// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/TokenA.sol";
import "../src/TokenB.sol";

contract AMMHandler is Test {
    AMM public amm;

    constructor(AMM _amm) {
        amm = _amm;
    }

    function swapAtoB(uint amountIn) public {
        amountIn = bound(amountIn, 1, 1000 ether);
        amm.swapAtoB(amountIn, 0);
    }

    function swapBtoA(uint amountIn) public {
        amountIn = bound(amountIn, 1, 1000 ether);
        amm.swapBtoA(amountIn, 0);
    }

    function addLiquidity(uint amountA, uint amountB) public {
        amountA = bound(amountA, 1, 1000 ether);
        amountB = bound(amountB, 1, 1000 ether);
        amm.addLiquidity(amountA, amountB);
    }
}

contract AMMTest is Test {
    AMM amm;
    TokenA tokenA;
    TokenB tokenB;
    AMMHandler handler;

    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        tokenA = new TokenA();
        tokenB = new TokenB();
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.mint(user1, 1000000 ether);
        tokenB.mint(user1, 1000000 ether);

        tokenA.mint(user2, 1000000 ether);
        tokenB.mint(user2, 1000000 ether);

        vm.startPrank(user1);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        handler = new AMMHandler(amm);
        tokenA.mint(address(handler), 10000000 ether);
        tokenB.mint(address(handler), 10000000 ether);
        vm.startPrank(address(handler));
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.prank(user1);
        amm.addLiquidity(10000 ether, 10000 ether);

        targetContract(address(handler));
    }

    function test_AddLiquidityUser1() public {
        vm.startPrank(user1);
        uint lp = amm.addLiquidity(1000, 1000);
        vm.stopPrank();

        assertTrue(lp > 0);
        assertEq(amm.reserveA(), 10000 ether + 1000);
        assertEq(amm.reserveB(), 10000 ether + 1000);
    }

    function test_AddLiquidityUser2() public {
        vm.prank(user2);
        uint lp2 = amm.addLiquidity(1000 ether, 1000 ether);
        assertTrue(lp2 > 0);
        assertEq(amm.reserveA(), 11000 ether);
        assertEq(amm.reserveB(), 11000 ether);
    }

    function test_RemoveLiquidityPartial() public {
        vm.startPrank(user1);
        uint lp = amm.addLiquidity(1000, 1000);
        amm.removeLiquidity(lp / 2);
        vm.stopPrank();
        assertTrue(amm.reserveA() > 0);
    }

    function test_RemoveLiquidityFull() public {
        vm.startPrank(user2);
        uint lp = amm.addLiquidity(1000, 1000);
        amm.removeLiquidity(lp);
        vm.stopPrank();
    }

    function test_SwapAtoB() public {
        uint balanceBBefore = tokenB.balanceOf(user2);

        vm.prank(user2);
        amm.swap(address(tokenA), 100, 0);

        uint balanceBAfter = tokenB.balanceOf(user2);
        assertTrue(balanceBAfter > balanceBBefore);
    }

    function test_SwapBtoA() public {
        uint balanceABefore = tokenA.balanceOf(user2);

        vm.prank(user2);
        amm.swap(address(tokenB), 100, 0);

        uint balanceAAfter = tokenA.balanceOf(user2);
        assertTrue(balanceAAfter > balanceABefore);
    }

    function test_RevertIf_SlippageError() public {
        vm.prank(user2);
        vm.expectRevert("Slippage error: amountOut < minAmountOut");
        amm.swap(address(tokenA), 100, 10000);
    }

    function test_SlippagePass() public {
        vm.prank(user2);
        amm.swap(address(tokenA), 100, 90);
    }

    function test_RevertIf_AddLiquidityZero() public {
        vm.prank(user1);
        vm.expectRevert("Invalid amounts");
        amm.addLiquidity(0, 0);
    }

    function test_RevertIf_RemoveLiquidityZero() public {
        vm.prank(user1);
        vm.expectRevert("Invalid LP amount");
        amm.removeLiquidity(0);
    }

    function test_RevertIf_SwapZero() public {
        vm.prank(user2);
        vm.expectRevert("Invalid amountIn");
        amm.swap(address(tokenA), 0, 0);
    }

    function test_SwapLargeValues() public {
        vm.prank(user1);
        amm.addLiquidity(500000 ether, 500000 ether);

        vm.prank(user2);
        uint out = amm.swap(address(tokenA), 100_000 ether, 0);
        assertTrue(out > 0);
    }

    function test_SwapHelpers() public {
        vm.startPrank(user2);
        uint outB = amm.swapAtoB(100, 0);
        assertTrue(outB > 0);

        uint outA = amm.swapBtoA(100, 0);
        assertTrue(outA > 0);
        vm.stopPrank();
    }

    function test_RevertIf_AddLiquidityInsufficientBalance() public {
        address user3 = address(0x3);
        vm.prank(user3);
        vm.expectRevert("Transfer failed");
        amm.addLiquidity(100, 100);
    }

    function test_RevertIf_InvalidTokenSwap() public {
        address badToken = address(0x99);
        vm.prank(user2);
        vm.expectRevert("Invalid tokenIn");
        amm.swap(badToken, 100, 0);
    }

    function testFuzz_Swap(uint amount) public {
        amount = bound(amount, 1e12, 1000 ether);

        vm.prank(user1);
        uint out = amm.swapAtoB(amount, 0);
        assertTrue(out > 0);
    }

    function invariant_K_does_not_decrease() public {
        uint kOld = 10000 ether * 10000 ether;
        uint kNew = amm.reserveA() * amm.reserveB();
        assertTrue(kNew >= kOld);
    }
}
