// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/yield-utils-v2/contracts/mocks/ERC20Mock.sol";
import "lib/yield-utils-v2/contracts/token/IERC20.sol";

/**
@title Fractional Wrapper
@author Calnix
@dev Contract allows users to exchange a pre-specified ERC20 token for some other wrapped ERC20 tokens.
@notice Wrapped tokens will be burned, when user withdraws their deposited tokens.
*/

contract FractionalizedWrapper is ERC20Mock {

    ///@dev Exchange rate at inception: 1 DAI = 1 yvDAI
    uint exRate = 1*10**27;

    ///@notice ERC20 interface specifying token contract functions
    ///@dev For constant variables, the value has to be fixed at compile-time, while for immutable, it can still be assigned at construction time.
    IERC20 public immutable asset;    
    
    /// @notice Emit event when ERC20 tokens are deposited into Fractionalized Wrapper
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    
    /// @notice Emit event when ERC20 tokens are withdrawn from Fractionalized Wrapper
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner,uint256 assets, uint256 shares);

    ///@notice Creates a new wrapper token for a specified token 
    ///@dev Token will have 18 decimal places as ERC20Mock inherits from ERC20Permit
    ///@param asset_ Address of underlying ERC20 token (e.g. DAI)
    ///@param tokenName Name of FractionalWrapper tokens 
    ///@param tokenSymbol Symbol of FractionalWrapper tokens (e.g. yvDAI)
    constructor(IERC20 asset_, string memory tokenName, string memory tokenSymbol) ERC20Mock(tokenName, tokenSymbol) {
        asset = asset_;
    }


    /// @notice User to deposit underlying tokens for FractionalWrapper tokens
    /// @dev Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens
    /// @param assets The amount of underlying tokens to deposit
    /// @param receiver Address of receiver of Fractional Wrapper shares
    function deposit(uint assets, address receiver) external returns(uint shares) {       
        shares = convertToShares(assets);

        //transfer DAI from user
        bool success = asset.transferFrom(receiver, address(this), assets);
        require(success, "Deposit failed!");   

        //mint yvDAI to user
        bool sent = _mint(receiver,convertToShares(assets));
        require(sent, "Mint failed!"); 

        emit Deposit(msg.sender, receiver, assets, shares);  
    }


    /// @notice User burns wrapped tokens, receiving udnerlying tokens; based on the exchange rate.
    /// @dev Burns shares from owner and sends exactly assets of underlying tokens to receiver
    /// @param assets The amount of underlying tokens to withdraw
    /// @param receiver Address of receiver of underlying tokens
    /// @param owner Address of owner of Fractional Wrapper shares
    function withdraw(uint assets, address receiver, address owner) external returns(uint shares) {
        shares = convertToAssets(assets);
        
        // MUST support a withdraw flow where the shares are burned from owner directly where owner is msg.sender,
        // OR msg.sender has ERC-20 approval over the shares of owner
        if(msg.sender != owner){
            uint allowedShares = _allowance[owner][receiver] ;
            require(allowedShares >= shares, "Allowance exceeded!");
            _allowance[owner][receiver] = allowedShares - shares;
        }
        
        //burn yvDAI 
        burn(owner, shares);
        
        //transfer assets
        bool success = asset.transfer(receiver, assets);
        require(success, "Transfer failed!"); 

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }


    ///@dev set exchange rate 
    function setExchangeRate(uint exRate_) public {
        exRate = exRate_;
    }

    ///@notice calculate how much yvDAI user should get based on exchange rate
    ///@dev exRate(27 dp precision) | both assets and shares are 18 dp precision
    function convertToShares(uint assets) public view returns(uint shares){
        return (assets)*(exRate / 10**27);
    }

    ///@notice calculate how much DAI user should get based on exchange rate
    ///@dev exRate(27 dp precision) | both assets and shares are 18 dp precision
    function convertToAssets(uint shares) public view returns(uint assets){
        return (shares)/(exRate / 10**27);
    }
    
    //Note that any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in share price
    function previewDeposit(uint assets) public view returns(uint shares) {
        return convertToShares(assets);
    }

    //Note that any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in share price
    function previewWithdraw(uint assets) public view returns(uint shares) {
        return convertToShares(assets);
    }

}