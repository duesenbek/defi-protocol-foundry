// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./TokenA.sol";
import "./TokenB.sol";
import "./LPToken.sol";

contract AMM {
    address public tokenA;
    address public tokenB;
    
    uint256 public reserveA;
    uint256 public reserveB;
    
    LPToken public lpToken;
    
    event LiquidityAdded(address user, uint amountA, uint amountB);
    event LiquidityRemoved(address user, uint amountA, uint amountB);
    event Swap(address user, address tokenIn, uint amountIn, uint amountOut);
    
    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        lpToken = new LPToken();
    }
    
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    
    function min(uint x, uint y) internal pure returns (uint) {
        return x <= y ? x : y;
    }

    function _transferFrom(address _token, address _from, address _to, uint _amount) private {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _from, _to, _amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed"); 
    }

    function _transfer(address _token, address _to, uint _amount) private {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSignature("transfer(address,uint256)", _to, _amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    function _balanceOf(address _token, address _account) private view returns (uint) {
        (bool success, bytes memory data) = _token.staticcall(
            abi.encodeWithSignature("balanceOf(address)", _account)
        );
        require(success, "balanceOf failed");
        return abi.decode(data, (uint));
    }
    
    function addLiquidity(uint amountA, uint amountB) external returns (uint lp) {
        require(amountA > 0 && amountB > 0, "Invalid amounts");
        
        _transferFrom(tokenA, msg.sender, address(this), amountA);
        _transferFrom(tokenB, msg.sender, address(this), amountB);
        
        uint totalLP = lpToken.totalSupply();
        if (totalLP == 0) {
            lp = sqrt(amountA * amountB);
        } else {
            lp = min(
                (amountA * totalLP) / reserveA,
                (amountB * totalLP) / reserveB
            );
        }
        
        require(lp > 0, "Minting 0 LP");
        
        lpToken.mint(msg.sender, lp);
        
        reserveA = _balanceOf(tokenA, address(this));
        reserveB = _balanceOf(tokenB, address(this));
        
        emit LiquidityAdded(msg.sender, amountA, amountB);
    }
    
    function removeLiquidity(uint lpAmount) external {
        require(lpAmount > 0, "Invalid LP amount");
        
        uint totalLP = lpToken.totalSupply();
        require(totalLP > 0, "No liquidity");
        
        uint amountA = (lpAmount * reserveA) / totalLP;
        uint amountB = (lpAmount * reserveB) / totalLP;
        
        lpToken.burn(msg.sender, lpAmount);
        
        _transfer(tokenA, msg.sender, amountA);
        _transfer(tokenB, msg.sender, amountB);
        
        reserveA = _balanceOf(tokenA, address(this));
        reserveB = _balanceOf(tokenB, address(this));
        
        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }
    
    function swap(address tokenIn, uint amountIn, uint minAmountOut) public returns (uint amountOut) {
        require(amountIn > 0, "Invalid amountIn");
        require(tokenIn == tokenA || tokenIn == tokenB, "Invalid tokenIn");
        
        bool isTokenA = tokenIn == tokenA;
        address tokenOut = isTokenA ? tokenB : tokenA;
        
        uint resIn = isTokenA ? reserveA : reserveB;
        uint resOut = isTokenA ? reserveB : reserveA;
        
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * resOut;
        uint denominator = (resIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
        
        require(amountOut >= minAmountOut, "Slippage error: amountOut < minAmountOut");
        
        _transferFrom(tokenIn, msg.sender, address(this), amountIn);
        _transfer(tokenOut, msg.sender, amountOut);
        
        reserveA = _balanceOf(tokenA, address(this));
        reserveB = _balanceOf(tokenB, address(this));
        
        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }
    
    function swapAtoB(uint amountIn, uint minAmountOut) external returns (uint) {
        return swap(tokenA, amountIn, minAmountOut);
    }
    
    function swapBtoA(uint amountIn, uint minAmountOut) external returns (uint) {
        return swap(tokenB, amountIn, minAmountOut);
    }
}
