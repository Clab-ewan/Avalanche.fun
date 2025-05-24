// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {ERC20TokenFactory} from "../src/Erc20Factory.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

/**
 * @title FundSubscription
 * @dev Script to fund an existing factory's VRF subscription with LINK tokens
 */
contract FundSubscription is Script {
    // LINK token address on Avalanche Fuji testnet
    address public constant LINK_TOKEN = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;

    // Default amount of LINK to fund the subscription with (1 LINK = 10^18)
    uint256 public constant DEFAULT_LINK_FUNDING_AMOUNT = 2 * 10 ** 18; // 2 LINK

    function run() public {
        // Load configuration
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("AVAX_PRIVATE_KEY");

        // Get the funding amount, defaulting to 2 LINK if not specified
        uint256 linkAmount = vm.envOr("LINK_AMOUNT", DEFAULT_LINK_FUNDING_AMOUNT);

        // Log pre-funding information
        console.log("Funding factory at address:", factoryAddress);
        console.log("LINK funding amount:", linkAmount);

        // Get the factory contract instance
        ERC20TokenFactory factory = ERC20TokenFactory(factoryAddress);

        // Display subscription information before funding
        uint256 subscriptionId = factory.getSubscriptionId();
        console.log("VRF Subscription ID:", subscriptionId);

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Get LINK token contract
        LinkTokenInterface link = LinkTokenInterface(LINK_TOKEN);

        // Check the deployer's LINK balance
        address deployer = vm.addr(deployerPrivateKey);
        uint256 balance = link.balanceOf(deployer);
        console.log("Deployer LINK balance:", balance);

        require(balance >= linkAmount, "Not enough LINK tokens in deployer's wallet");

        // Transfer LINK tokens to the factory contract
        bool transferSuccess = link.transfer(factoryAddress, linkAmount);
        require(transferSuccess, "LINK transfer failed");
        console.log("Transferred", linkAmount, "LINK to factory contract");

        // Call the fundSubscription function on the factory
        factory.fundSubscription(linkAmount);

        // End broadcasting transactions
        vm.stopBroadcast();
    }
}
