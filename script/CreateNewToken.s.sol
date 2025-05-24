// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {CustomERC20Token} from "../src/CustomERC20Token.sol";
import {ERC20TokenFactory} from "../src/Erc20Factory.sol";

contract CreateNewToken is Script {
    // Creation fee in wei (0.01 ether = 10^16 wei)
    ERC20TokenFactory public factory;

    function run() public {
        // Retrieve private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("AVAX_PRIVATE_KEY");    
        address _erc20FactoryAddress = 0x174A0F11071C640B9B1b062551481F83F52d1643;   

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the ERC20CustomToken contract
        factory = ERC20TokenFactory(_erc20FactoryAddress);
        uint256 creationFee = factory.creationFee();
        CustomERC20Token newToken = CustomERC20Token(address(factory.createToken{value: creationFee}(
            "My Custom Token",
            "MCT",
            18,
            1000000 * 10**18 // Initial supply of 1 million tokens with 18 decimals
        )));
        // Log the deployment address
        console.log("ERC20TokenFactory deployed at:", address(factory));
        console.log("Creation fee set to:", creationFee, "wei");
        console.log("New token deployed at:", address(newToken));
        console.log("Token Name:", newToken.name());
        console.log("Token Symbol:", newToken.symbol());
        console.log("Token Decimals:", newToken.decimals());
        console.log("Initial Supply:", newToken.totalSupply() / 10**newToken.decimals(), "tokens");
        console.log("Token Owner:", newToken.owner());
        console.log("Token Address:", address(newToken));
        // End broadcasting transactions
        vm.stopBroadcast();
    }
}
