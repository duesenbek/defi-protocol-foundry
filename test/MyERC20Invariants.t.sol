// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MyERC20.sol";

contract TokenHandler {
    MyERC20 public token;

    constructor(MyERC20 _token) {
        token = _token;
    }

    function transfer(address to, uint256 amount) public {
        token.transfer(to, amount);
    }

    function approve(address spender, uint256 amount) public {
        token.approve(spender, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public {
        token.transferFrom(from, to, amount);
    }
}

contract MyERC20Invariants is Test {
    MyERC20 token;
    TokenHandler handler;

    function setUp() public {
        token = new MyERC20("Test Token", "TST");
        token.mint(address(this), 1000000 ether);
        token.mint(address(uint160(1)), 5000 ether);

        handler = new TokenHandler(token);

        token.transfer(address(handler), 100000 ether);

        targetContract(address(handler));
    }

    function invariant_TotalSupplyCannotChange() public {
        assertEq(token.totalSupply(), 1000000 ether + 5000 ether);
    }

    function invariant_BalanceCannotExceedTotalSupply() public {
        assertTrue(token.balanceOf(address(this)) <= token.totalSupply());
        assertTrue(token.balanceOf(address(handler)) <= token.totalSupply());
    }

    function invariant_TotalSupplyAlwaysGteBalances() public {
        uint256 sum = token.balanceOf(address(this)) + token.balanceOf(address(handler)) + token.balanceOf(address(uint160(1)));
        assertTrue(sum <= token.totalSupply());
    }
}
