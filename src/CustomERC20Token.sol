// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CustomERC20Token
 * @dev Basic ERC20 token implementation that can be deployed by the factory
 */
contract CustomERC20Token is ERC20, Ownable {
    uint8 private _decimals;
    
    constructor(
        string memory name,
        string memory symbol,
        uint8 tokenDecimals,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        _decimals = tokenDecimals;
        _mint(owner, initialSupply * 10**tokenDecimals);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Allows owner to mint additional tokens
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Allows owner to burn tokens from their balance
     */
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }
}