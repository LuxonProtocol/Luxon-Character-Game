// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {LuxonCharacter} from "../src/LuxonCharacter.sol";

contract DeployLuxonCharacter is Script {
    function run() external returns (LuxonCharacter) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        console.log("========================================");
        console.log("  LUXON PROTOCOL - Deployment Starting");
        console.log("========================================");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Balance:", vm.addr(deployerPrivateKey).balance / 1e18, "ETH");
        
        vm.startBroadcast(deployerPrivateKey);   
        
        LuxonCharacter game = new LuxonCharacter();
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("Contract Address:", address(game));
        console.log("Contract Name:", game.name());
        console.log("Contract Symbol:", game.symbol());
        console.log("Version:", game.VERSION());
        console.log("");
        
        return game;
    }
}


