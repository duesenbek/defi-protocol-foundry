// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MyERC20.sol";

contract MyERC20Test is Test {
    MyERC20 token;
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        token = new MyERC20("Test Token", "TST");
    }

    function test_Mint() public {
        token.mint(user1, 1000);
        assertEq(token.balanceOf(user1), 1000);
        assertEq(token.totalSupply(), 1000);
    }

    function test_RevertIf_MintZeroAddress() public {
        vm.expectRevert(MyERC20.ZeroAddress.selector);
        token.mint(address(0), 100);
    }

    function test_Transfer() public {
        token.mint(address(this), 1000);
        token.transfer(user1, 500);
        assertEq(token.balanceOf(user1), 500);
        assertEq(token.balanceOf(address(this)), 500);
    }

    function test_RevertIf_TransferInsufficientBalance() public {
        token.mint(address(this), 100);
        vm.expectRevert(MyERC20.InsufficientBalance.selector);
        token.transfer(user1, 200);
    }

    function test_RevertIf_TransferToZeroAddress() public {
        token.mint(address(this), 100);
        vm.expectRevert(MyERC20.ZeroAddress.selector);
        token.transfer(address(0), 50);
    }

    function test_Approve() public {
        token.approve(user1, 500);
        assertEq(token.allowance(address(this), user1), 500);
    }

    function test_TransferFrom() public {
        token.mint(address(this), 1000);
        token.approve(user1, 500);

        vm.prank(user1);
        token.transferFrom(address(this), user2, 500);

        assertEq(token.balanceOf(user2), 500);
        assertEq(token.allowance(address(this), user1), 0);
        assertEq(token.balanceOf(address(this)), 500);
    }

    function test_RevertIf_TransferFromInsufficientAllowance() public {
        token.mint(address(this), 1000);
        token.approve(user1, 100);

        vm.prank(user1);
        vm.expectRevert(MyERC20.InsufficientAllowance.selector);
        token.transferFrom(address(this), user2, 500);
    }

    function test_RevertIf_TransferFromInsufficientBalance() public {
        token.mint(address(this), 100);
        token.approve(user1, 500);

        vm.prank(user1);
        vm.expectRevert(MyERC20.InsufficientBalance.selector);
        token.transferFrom(address(this), user2, 200);
    }

    function test_TransferMaxAmount() public {
        uint256 maxAmount = type(uint256).max;
        token.mint(address(this), maxAmount);

        token.transfer(user1, maxAmount);

        assertEq(token.balanceOf(user1), maxAmount);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_TransferFromMaxAmount() public {
        uint256 maxAmount = type(uint256).max;
        token.mint(address(this), maxAmount);
        token.approve(user1, maxAmount);

        vm.prank(user1);
        token.transferFrom(address(this), user2, maxAmount);

        assertEq(token.balanceOf(user2), maxAmount);
    }

    function testFuzz_Transfer(uint amount) public {
        vm.assume(amount < type(uint256).max);

        token.mint(address(this), amount);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(address(this)), 0);
    }
}
