// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title VRFSubscriptionManager
 * @dev Manages Chainlink VRF v2.5 subscriptions for tokens created by the factory
 */
contract VRFSubscriptionManager is VRFConsumerBaseV2Plus {
    // VRF Configuration
    IVRFCoordinatorV2Plus private immutable COORDINATOR;
    LinkTokenInterface private immutable LINKTOKEN;
    bytes32 public keyHash;
    uint256 private s_subscriptionId;

    // Contract owner (factory address) - renamed to managerOwner to avoid conflict
    address public managerOwner;

    // Events for VRF subscription management
    event SubscriptionCreated(uint256 subscriptionId);
    event SubscriptionFunded(uint256 subscriptionId, uint256 amount);
    event ConsumerAdded(uint256 subscriptionId, address consumer);
    event ConsumerRemoved(uint256 subscriptionId, address consumer);

    // Modifier to restrict access to the manager owner
    modifier onlyManagerOwner() {
        require(msg.sender == managerOwner, "Not manager owner");
        _;
    }

    /**
     * @dev Constructor initializes the VRF subscription manager
     * @param vrfCoordinator Address of the VRF Coordinator
     * @param linkToken Address of the LINK token
     * @param _keyHash Key hash for the VRF request
     */
    constructor(address vrfCoordinator, address linkToken, bytes32 _keyHash) VRFConsumerBaseV2Plus(vrfCoordinator) {
        COORDINATOR = IVRFCoordinatorV2Plus(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(linkToken);
        keyHash = _keyHash;
        managerOwner = msg.sender;

        // Create a new subscription when contract is deployed
        createNewSubscription();
    }

    /**
     * @dev Required override function for VRFConsumerBaseV2Plus
     */
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata /* randomWords */ ) internal override {
        // Not used in the manager, but required by VRFConsumerBaseV2Plus
        // The token contracts handle their own randomness fulfillment
    }

    /**
     * @dev Create a new VRF subscription
     */
    function createNewSubscription() public onlyManagerOwner {
        // Create a new subscription
        s_subscriptionId = COORDINATOR.createSubscription();

        // Add this contract as a consumer (just to ensure the subscription is properly initialized)
        COORDINATOR.addConsumer(s_subscriptionId, address(this));

        emit SubscriptionCreated(s_subscriptionId);
    }

    /**
     * @dev Fund the VRF subscription with LINK tokens
     * Requires the contract to have LINK tokens
     * @param amount Amount of LINK to add to the subscription (1000000000000000000 = 1 LINK)
     */
    function topUpSubscription(uint256 amount) external onlyManagerOwner {
        require(s_subscriptionId != 0, "Subscription not created");
        require(LINKTOKEN.balanceOf(address(this)) >= amount, "Not enough LINK");

        LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(s_subscriptionId));

        emit SubscriptionFunded(s_subscriptionId, amount);
    }

    /**
     * @dev Add a consumer to the VRF subscription
     * @param consumerAddress Address of the consumer to add
     */
    function addConsumer(address consumerAddress) external onlyManagerOwner {
        require(s_subscriptionId != 0, "Subscription not created");
        COORDINATOR.addConsumer(s_subscriptionId, consumerAddress);
        emit ConsumerAdded(s_subscriptionId, consumerAddress);
    }

    /**
     * @dev Remove a consumer from the VRF subscription
     * @param consumerAddress Address of the consumer to remove
     */
    function removeConsumer(address consumerAddress) external onlyManagerOwner {
        require(s_subscriptionId != 0, "Subscription not created");
        COORDINATOR.removeConsumer(s_subscriptionId, consumerAddress);
        emit ConsumerRemoved(s_subscriptionId, consumerAddress);
    }

    /**
     * @dev Cancel the VRF subscription and send remaining LINK to a specified address
     * @param receivingWallet Address to send remaining LINK to
     */
    function cancelSubscription(address receivingWallet) external onlyManagerOwner {
        require(s_subscriptionId != 0, "Subscription not created");
        COORDINATOR.cancelSubscription(s_subscriptionId, receivingWallet);
        s_subscriptionId = 0;
    }

    /**
     * @dev Get the current VRF subscription ID
     */
    function getSubscriptionId() external view returns (uint256) {
        return s_subscriptionId;
    }

    /**
     * @dev Withdraw LINK tokens from the contract
     * @param amount Amount of LINK to withdraw
     * @param to Address to send LINK to
     */
    function withdrawLink(uint256 amount, address to) external onlyManagerOwner {
        require(LINKTOKEN.balanceOf(address(this)) >= amount, "Not enough LINK");
        LINKTOKEN.transfer(to, amount);
    }

    /**
     * @dev Transfer ownership of the manager to a new address
     * @param newOwner Address of the new owner
     */
    function transferManagerOwnership(address newOwner) external onlyManagerOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        managerOwner = newOwner;
    }
}
