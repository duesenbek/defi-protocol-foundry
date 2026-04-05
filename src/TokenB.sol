// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MyERC20.sol";

contract TokenB is MyERC20 {
    constructor() MyERC20("Token B", "TKB") {}
}
