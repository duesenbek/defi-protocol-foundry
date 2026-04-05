// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Lending.sol";
import "../src/MyERC20.sol";

contract LendingTest is Test {
    Lending lending;
    MyERC20 token;

    address user1 = address(0x1);
    address user2 = address(0x2);
    address liquidator = address(0x3);

    function setUp() public {
        token = new MyERC20("Lending Token", "LTK");
        lending = new Lending(address(token));

        token.mint(user1, 100000 ether);
        token.mint(user2, 100000 ether);
        token.mint(liquidator, 100000 ether);
        token.mint(address(lending), 1000000 ether);

        vm.prank(user1);
        token.approve(address(lending), type(uint256).max);

        vm.prank(user2);
        token.approve(address(lending), type(uint256).max);

        vm.prank(liquidator);
        token.approve(address(lending), type(uint256).max);
    }

    function test_Deposit() public {
        vm.prank(user1);
        lending.deposit(1000 ether);

        assertEq(lending.collateral(user1), 1000 ether);
    }

    function test_RevertIf_DepositZero() public {
        vm.prank(user1);
        vm.expectRevert("Amount must be > 0");
        lending.deposit(0);
    }

    function test_Borrow() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);
        lending.borrow(750 ether);
        vm.stopPrank();

        assertEq(lending.debt(user1), 750 ether);
    }

    function test_RevertIf_BorrowExceedsLimit() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);

        vm.expectRevert("Borrow exceeds LTV limit");
        lending.borrow(751 ether);
        vm.stopPrank();
    }

    function test_BorrowMultipleTimes() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);
        lending.borrow(300 ether);
        lending.borrow(400 ether);
        vm.stopPrank();

        assertEq(lending.debt(user1), 700 ether);
    }

    function test_RevertIf_BorrowMultipleExceedsLimit() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);
        lending.borrow(500 ether);

        vm.expectRevert("Borrow exceeds LTV limit");
        lending.borrow(300 ether);
        vm.stopPrank();
    }

    function test_Repay() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);
        lending.borrow(500 ether);
        lending.repay(200 ether);
        vm.stopPrank();

        assertEq(lending.debt(user1), 300 ether);
    }

    function test_RepayFull() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);
        lending.borrow(500 ether);
        lending.repay(500 ether);
        vm.stopPrank();

        assertEq(lending.debt(user1), 0);
    }

    function test_RevertIf_RepayMoreThanDebt() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);
        lending.borrow(500 ether);

        vm.expectRevert("Repay exceeds debt");
        lending.repay(600 ether);
        vm.stopPrank();
    }

    function test_Withdraw() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);
        lending.withdraw(500 ether);
        vm.stopPrank();

        assertEq(lending.collateral(user1), 500 ether);
    }

    function test_RevertIf_WithdrawUnsafe() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);
        lending.borrow(750 ether);

        vm.expectRevert("Withdraw would make position unsafe");
        lending.withdraw(100 ether);
        vm.stopPrank();
    }

    function test_LiquidateUnsafe() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);
        lending.borrow(750 ether);
        vm.stopPrank();

        bytes32 debtSlot = keccak256(abi.encode(user1, uint256(2)));
        vm.store(address(lending), debtSlot, bytes32(uint256(800 ether)));

        vm.prank(liquidator);
        lending.liquidate(user1);

        assertEq(lending.collateral(user1), 0);
        assertEq(lending.debt(user1), 0);
    }

    function test_RevertIf_LiquidateSafe() public {
        vm.startPrank(user1);
        lending.deposit(1000 ether);
        lending.borrow(500 ether);
        vm.stopPrank();

        vm.prank(liquidator);
        vm.expectRevert("Position is safe, cannot liquidate");
        lending.liquidate(user1);
    }

    function testFuzz_Borrow(uint256 amount) public {
        uint256 depositAmount = 10000 ether;
        uint256 maxBorrow = (depositAmount * 75) / 100;
        amount = bound(amount, 1, maxBorrow);

        vm.startPrank(user1);
        lending.deposit(depositAmount);
        lending.borrow(amount);
        vm.stopPrank();

        assertEq(lending.debt(user1), amount);
        assertTrue(lending.debt(user1) <= maxBorrow);
    }

    function invariant_DebtNeverExceedsLTV() public view {
        uint256 col1 = lending.collateral(user1);
        uint256 dbt1 = lending.debt(user1);
        if (col1 > 0) {
            assertTrue(dbt1 <= (col1 * 75) / 100);
        }
    }
}
