// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MyERC20.sol";

contract Lending {
    MyERC20 public token;

    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;

    uint256 public constant LTV = 75;

    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Liquidate(address indexed user);

    constructor(address _token) {
        token = MyERC20(_token);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");

        token.transferFrom(msg.sender, address(this), amount);
        collateral[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");

        uint256 maxBorrow = (collateral[msg.sender] * LTV) / 100;
        require(debt[msg.sender] + amount <= maxBorrow, "Borrow exceeds LTV limit");

        debt[msg.sender] += amount;
        token.transfer(msg.sender, amount);

        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(debt[msg.sender] >= amount, "Repay exceeds debt");

        token.transferFrom(msg.sender, address(this), amount);
        debt[msg.sender] -= amount;

        emit Repay(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(collateral[msg.sender] >= amount, "Insufficient collateral");

        uint256 newCollateral = collateral[msg.sender] - amount;
        uint256 maxBorrow = (newCollateral * LTV) / 100;
        require(debt[msg.sender] <= maxBorrow, "Withdraw would make position unsafe");

        collateral[msg.sender] -= amount;
        token.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    function liquidate(address user) external {
        uint256 maxBorrow = (collateral[user] * LTV) / 100;
        require(debt[user] > maxBorrow, "Position is safe, cannot liquidate");



        collateral[user] = 0;
        debt[user] = 0;

        emit Liquidate(user);
    }
}
