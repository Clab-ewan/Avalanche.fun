// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CustomERC20Token} from "./CustomERC20Token.sol";

/**
 * @title ERC20TokenFactory
 * @dev Factory contract for deploying ERC20 tokens
*/
contract ERC20TokenFactory {
    // Event emitted when a new token is created
    event TokenCreated(
        address indexed tokenAddress,
        address indexed owner,
        string name,
        string symbol,
        uint8 decimals,
        uint256 initialSupply
    );
    
    // Array to store all created token addresses
    address[] public deployedTokens;
    
    // Mapping from owner to their created tokens
    mapping(address => address[]) public ownerToTokens;
    
    // Mapping to check if an address is a token created by this factory
    mapping(address => bool) public isFactoryToken;
    
    // Factory owner
    address public factoryOwner;
    
    // Fee for creating a token (in wei)
    uint256 public creationFee;
    
    constructor(uint256 _creationFee) {
        factoryOwner = msg.sender;
        creationFee = _creationFee;
    }
    
    modifier onlyFactoryOwner() {
        require(msg.sender == factoryOwner, "Not factory owner");
        _;
    }
    
    /**
     * @dev Creates a new ERC20 token
     * @param name Name of the token
     * @param symbol Symbol of the token
     * @param decimals Number of decimals for the token
     * @param initialSupply Initial supply of tokens (without decimals)
     * @return Address of the newly created token
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply
    ) external payable returns (address) {
        require(msg.value >= creationFee, "Insufficient fee");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(decimals <= 18, "Decimals cannot exceed 18");
        require(initialSupply > 0, "Initial supply must be greater than 0");
        
        // Deploy new token contract
        CustomERC20Token newToken = new CustomERC20Token(
            name,
            symbol,
            decimals,
            initialSupply,
            msg.sender
        );
        
        address tokenAddress = address(newToken);
        
        // Store token information
        deployedTokens.push(tokenAddress);
        ownerToTokens[msg.sender].push(tokenAddress);
        isFactoryToken[tokenAddress] = true;
        
        // Emit event
        emit TokenCreated(
            tokenAddress,
            msg.sender,
            name,
            symbol,
            decimals,
            initialSupply
        );
        
        return tokenAddress;
    }
    
    /**
     * @dev Get all tokens created by this factory
     */
    function getAllTokens() external view returns (address[] memory) {
        return deployedTokens;
    }
    
    /**
     * @dev Get tokens created by a specific owner
     */
    function getTokensByOwner(address owner) external view returns (address[] memory) {
        return ownerToTokens[owner];
    }
    
    /**
     * @dev Get the total number of tokens created
     */
    function getTotalTokensCreated() external view returns (uint256) {
        return deployedTokens.length;
    }
    
    /**
     * @dev Update creation fee (only factory owner)
     */
    function setCreationFee(uint256 _newFee) external onlyFactoryOwner {
        creationFee = _newFee;
    }
    
    /**
     * @dev Transfer factory ownership
     */
    function transferFactoryOwnership(address newOwner) external onlyFactoryOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        factoryOwner = newOwner;
    }
    
    /**
     * @dev Withdraw collected fees (only factory owner)
     */
    function withdrawFees() external onlyFactoryOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        (bool success, ) = payable(factoryOwner).call{value: balance}("");
        require(success, "Fee withdrawal failed");
    }
}