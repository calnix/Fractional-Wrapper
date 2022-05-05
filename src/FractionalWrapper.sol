// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "yield-utils-v2/contracts/mocks/ERC20Mock.sol";
import "yield-utils-v2/contracts/token/IERC20.sol";

import "src/YearnVaultMock.sol"; 

/**
@title An ERC20 Token Wrapper
@author Calnix
@dev Contract allows users to exchange a pre-specified ERC20 token for some other wrapped ERC20 tokens.
@notice Wrapped tokens will be burned, when user withdraws their deposited tokens.
*/

contract FractionalizedWrapper is ERC20Mock, YearnVault {

    ///@notice ERC20 interface specifying token contract functions
    ///@dev For constant variables, the value has to be fixed at compile-time, while for immutable, it can still be assigned at construction time.
    IERC20 public immutable token;    
    
    ///@notice Yearn Vault contract
    YearnVaultMock public immutable yvToken;  

    ///@notice mapping addresses to their respective underlying token balances
    mapping(address => uint) public balances;

    /// @notice Emit event when ERC20 tokens are deposited into Fractionalized Wrapper
    event Deposit(address indexed from, uint amount);
    
    /// @notice Emit event when ERC20 tokens are withdrawn from Fractionalized Wrapper
    event Withdraw(address indexed from, uint amount);

    ///@notice Creates a new wrapper token for a specified token 
    ///@dev Token will have 18 decimal places as ERC20Mock inherits from ERC20Permit
    ///@param token_ Address of underlying ERC20 token (e.g. DAI)
    ///@param yvToken_ Address of Yearn Vault
    ///@param tokenName Name of FractionalWrapper shares 
    ///@param tokenSymbol Symbol of FractionalWrapper shares (e.g. FWS)
    constructor(IERC20 token_, YearnVaultMock yvToken_, string memory tokenName, string memory tokenSymbol) ERC20Mock(tokenName, tokenSymbol) {
        token = token_;
        yvToken = yvToken_;
    }

    /// @notice User to despoit underlying tokens for FractionalWrapper shares
    /// @dev 
    /// @param amount The amount of underlying tokens to deposit
    function deposit(uint amount) public {        
        balances[msg.sender] += amount;
      
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Deposit failed!"); 
        emit Deposit(msg.sender, amount);  

        yvToken.deposit(amount);


    }

    /// @notice User burns wrapped ERC20 tokens, thereby receiving unwrapped ERC20 tokens.
    /// @dev Expect withdraw to revert if transfer fails
    /// @param amount The amount of ERC20 tokens to unwrap
    function withdraw(uint amount) public {
        burn(msg.sender, amount);
        
        bool success = token.transfer(msg.sender, amount);
        require(success, "Unwrapping failed!"); 

        emit Withdraw(msg.sender, amount);   
    }

}

