// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../contracts/test/TestERC20.sol";
import "../contracts/SimpleSwap.sol";
import "forge-std/console.sol";

contract MyScript is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);
        TestERC20 tokenB = new TestERC20("token B", "TKB");
        TestERC20 tokenA = new TestERC20("token A", "TKA");

        uint tokenADecimals = tokenA.decimals();
        uint tokenBDecimals = tokenB.decimals();
        SimpleSwap simpleSwap = new SimpleSwap(address(tokenA), address(tokenB));
        vm.stopBroadcast();
    }
}