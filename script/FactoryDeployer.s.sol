// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {ERC20TokenFactory} from "../src/Erc20Factory.sol";

contract FactoryDeployer is Script {
    // Creation fee in wei (0.01 ether = 10^16 wei)
    uint256 public constant CREATION_FEE = 0.01 ether;

    function run() public {
        // Retrieve private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("AVAX_PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the ERC20TokenFactory contract
        ERC20TokenFactory factory = new ERC20TokenFactory(CREATION_FEE);

        // Log the deployment address
        console.log("ERC20TokenFactory deployed at:", address(factory));
        console.log("Creation fee set to:", CREATION_FEE, "wei");

        // End broadcasting transactions
        vm.stopBroadcast();
    }
}
