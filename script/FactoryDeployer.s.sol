// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {ERC20TokenFactory} from "../src/Erc20Factory.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract FactoryDeployer is Script {
    // Creation fee in wei (0.01 ether = 10^16 wei)
    uint256 public constant CREATION_FEE = 0.0001 ether;
    uint256 deployerPrivateKey;

    // LINK token address on Avalanche Fuji testnet
    address public constant LINK_TOKEN = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;

    // Amount of LINK to fund the subscription with (1 LINK = 10^18)
    uint256 public constant LINK_FUNDING_AMOUNT = 2 * 10 ** 18; // 2 LINK

    function run() public {
        // Retrieve private key from environment variable
        deployerPrivateKey = vm.envUint("AVAX_PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the ERC20TokenFactory contract with VRF support
        ERC20TokenFactory factory = new ERC20TokenFactory(CREATION_FEE, 0xAd8cd7F31b4A09FedB2e93779b5011DE2aFd88e0);

        // Log the deployment address
        console.log("ERC20TokenFactory deployed at:", address(factory));
        console.log("Creation fee set to:", CREATION_FEE, "wei");
        console.log("Factory owner:", factory.factoryOwner());

        // Get the VRF Subscription Manager address
        address subscriptionManagerAddress = address(factory.subscriptionManager());
        console.log("VRF Subscription Manager deployed at:", subscriptionManagerAddress);
        console.log("VRF Subscription Manager owner:", factory.subscriptionManager().managerOwner());

        // Get the subscription ID
        uint256 subscriptionId = factory.getSubscriptionId();
        console.log("VRF Subscription ID created:", subscriptionId);

        // End broadcasting transactions
        vm.stopBroadcast();
    }

    /**
     * @dev Helper function to fund the subscription with LINK tokens
     * This is called within the script, but runs as a separate transaction
     */
    function fundSubscriptionWithLink(address factoryAddress, uint256 amount) external {
        // Get LINK token contract
        LinkTokenInterface link = LinkTokenInterface(LINK_TOKEN);

        // Check the deployer's LINK balance
        uint256 balance = link.balanceOf(msg.sender);
        require(balance >= amount, "Not enough LINK tokens in deployer's wallet");

        // Transfer LINK tokens to the factory contract
        bool transferSuccess = link.transfer(factoryAddress, amount);
        require(transferSuccess, "LINK transfer failed");

        // Call the fundSubscription function on the factory contract
        ERC20TokenFactory factory = ERC20TokenFactory(factoryAddress);
        factory.fundSubscription(amount);
    }
}
