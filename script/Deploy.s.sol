// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/MyERC20.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(1));
        
        vm.startBroadcast(deployerPrivateKey);

        MyERC20 token = new MyERC20("My Test Token", "MTK");

        vm.stopBroadcast();
    }
}
