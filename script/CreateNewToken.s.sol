// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {CustomERC20Token} from "../src/CustomERC20Token.sol";
import {ERC20TokenFactory} from "../src/Erc20Factory.sol";
import {VRFSubscriptionManager} from "../src/VRFSubscriptionManager.sol";

contract CreateNewToken is Script {
    // ERC20 Token Factory contract
    ERC20TokenFactory public factory;

    // Default token parameters
    string public constant TOKEN_NAME = "GamblingTokenBitch";
    string public constant TOKEN_SYMBOL = "GTB";
    uint8 public constant TOKEN_DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY = 1000000; // 1 million tokens (decimal conversion happens in the constructor)

    function run() public {
        // Retrieve private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("AVAX_PRIVATE_KEY");
        address _erc20FactoryAddress = 0x2CB5A989febF39FA77889682adA469d9942634C5;

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Connect to the factory
        factory = ERC20TokenFactory(_erc20FactoryAddress);
        uint256 creationFee = factory.creationFee();


        // Create the token with VRF support
        console.log("\n=== Creating New Token ===");
        console.log("Name:", TOKEN_NAME);
        console.log("Symbol:", TOKEN_SYMBOL);
        console.log("Decimals:", TOKEN_DECIMALS);
        console.log("Initial Supply:", INITIAL_SUPPLY, "tokens");

        address tokenAddress = factory.createToken{value: creationFee}(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            INITIAL_SUPPLY // Supply without decimals (constructor handles decimal conversion)
        );

        // Connect to the deployed token
        CustomERC20Token newToken = CustomERC20Token(tokenAddress);

        // Verify that the token was created properly
        console.log("\n=== Token Successfully Created ===");
        console.log("Factory address:", address(factory));
        console.log("Creation fee paid:", creationFee, "wei");
        console.log("New token deployed at:", address(newToken));
        console.log("Token Name:", newToken.name());
        console.log("Token Symbol:", newToken.symbol());
        console.log("Token Decimals:", newToken.decimals());
        console.log("Total Supply:", newToken.totalSupply() / 10 ** newToken.decimals(), "tokens");
        console.log("Token Owner:", newToken.owner());


        // Get VRF configuration
        (
            uint256 subscriptionId,
            bytes32 _keyHash,
            uint32 callbackGasLimit,
            uint16 requestConfirmations,
            uint32 numWords
        ) = newToken.getVRFConfig();

        console.log("VRF Configuration:");
        console.log("- Subscription ID:", subscriptionId);
        // console.log("- Key Hash:", _keyHash); // Not working in forge console
        console.log("- Callback Gas Limit:", callbackGasLimit);
        console.log("- Request Confirmations:", requestConfirmations);
        console.log("- Number of Words:", numWords);

        // Verify token is added as consumer to the subscription
        address subscriptionManagerAddress = address(factory.subscriptionManager());
        console.log("\n=== VRF Subscription Verification ===");
        console.log("VRF Subscription Manager:", subscriptionManagerAddress);
        console.log("Subscription ID from token:", subscriptionId);
        console.log("Subscription ID from factory:", factory.getSubscriptionId());

        // The subscription IDs should match
        require(subscriptionId == factory.getSubscriptionId(), "Subscription ID mismatch!");
        console.log("Subscription ID verification passed");

        // Get direct access to the subscription manager to verify the token is a consumer
        VRFSubscriptionManager subManager = VRFSubscriptionManager(subscriptionManagerAddress);

        // Log information about available VRF functionality
        console.log("\n=== Token Gambling Functionality ===");
        console.log("Minimum bet:", newToken.minimumBet() / 10 ** newToken.decimals(), "tokens");
        console.log("House edge:", newToken.houseEdge() / 100, "%");
        console.log("INFO: To place a bet, call placeBet(uint256 betAmount, bool useNativePayment)");
        console.log("- betAmount: Amount of tokens to bet");
        console.log("- useNativePayment: Set to true to pay for VRF in native tokens (AVAX), false to use LINK");

        // End broadcasting transactions
        vm.stopBroadcast();
    }
}
