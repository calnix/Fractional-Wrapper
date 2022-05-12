// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/yield-utils-v2/contracts/mocks/ERC20Mock.sol";
import "lib/yield-utils-v2/contracts/token/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
@title Fractional Wrapper
@author Calnix
@dev Contract allows users to exchange a pre-specified ERC20 token for some other wrapped ERC20 tokens.
@notice Wrapped tokens will be burned, when user withdraws their deposited tokens.
*/

contract FractionalWrapper is ERC20Mock, Ownable {

    ///@dev Exchange rate at inception: 1 underlying (DAI) == 1 share (yvDAI) | Ex-rate: 1 DAI/yvDAI = 0.5 -> 1 DAI gets you 1/2 yvDAI
    uint exRate = 1e27;

    ///@notice ERC20 interface specifying token contract functions
    ///@dev For constant variables, the value has to be fixed at compile-time, while for immutable, it can still be assigned at construction time.
    IERC20 public immutable asset;    
    
    /// @notice Emit event when ERC20 tokens are deposited into Fractionalized Wrapper
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    
    /// @notice Emit event when ERC20 tokens are withdrawn from Fractionalized Wrapper
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

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
        receiver = msg.sender;
        shares = convertToShares(assets);

        //transfer DAI from user
        bool success = asset.transferFrom(receiver, address(this), assets);
        require(success, "Deposit failed!");   

        //mint yvDAI to user
        bool sent = _mint(receiver, shares);
        require(sent, "Mint failed!"); 

        emit Deposit(msg.sender, receiver, assets, shares);  
    }


    /// @dev Burns shares from owner and sends exactly assets of underlying tokens to receiver; based on the exchange rate.
    /// @param assets The amount of underlying tokens to withdraw
    /// @param receiver Address of receiver of underlying tokens - DAI
    /// @param owner Address of owner of Fractional Wrapper shares - yvDAI
    function withdraw(uint assets, address receiver, address owner) external returns(uint shares) {
        shares = convertToShares(assets);
        
        // MUST support a withdraw flow where the shares are burned from owner directly where owner is msg.sender,
        // OR msg.sender has ERC-20 approval over the shares of owner
        if(msg.sender != owner){
            uint allowedShares = _allowance[owner][receiver] ;
            require(allowedShares >= shares, "Allowance exceeded!");
            _allowance[owner][receiver] = allowedShares - shares;
        }

        //burn wrapped tokens(shares) -> yvDAI 
        burn(owner, shares);
        
        //transfer assets
        bool success = asset.transfer(receiver, assets);
        require(success, "Transfer failed!"); 
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @dev Burns shares from owner and sends assets of underlying tokens to receiver; based on the exchange rate.
    /// @param shares The amount of wrapped tokens to redeem for underlying tokens (assets)
    /// @param receiver Address of receiver of underlying tokens - DAI
    /// @param owner Address of owner of Fractional Wrapper shares - yvDAI
    function redeem(uint shares, address receiver, address owner) external returns(uint assets) {
        assets = convertToAssets(shares);
        
        // MUST support a redeem flow where the shares are burned from owner directly where owner is msg.sender,
        // OR msg.sender has ERC-20 approval over the shares of owner
        if(msg.sender != owner){
            uint allowedShares = _allowance[owner][receiver] ;
            require(allowedShares >= shares, "Allowance exceeded!");
            _allowance[owner][receiver] = allowedShares - shares;
        }

        //burn wrapped tokens(shares) -> yvDAI 
        burn(owner, shares);
        
        //transfer assets
        bool success = asset.transfer(receiver, assets);
        require(success, "Transfer failed!"); 
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }



    /// @notice Only the owner can call to modify exchange rate
    /// @dev Exchange rate is of 1e27 precision | Ex-rate: 1 DAI/yvDAI = 0.5 -> 1 DAI gets you 1/2 yvDAI
    /// @param exRate_ New exchange rate
    function setExchangeRate(uint exRate_) external onlyOwner {
        exRate = exRate_;
    }

    /// @notice calculate how much yvDAI user should get based on exchange rate
    /// @dev exRate(27 dp precision) | both assets and shares are 18 dp precision
    /// @param assets Amount of underlying tokens (assets) to be converted to wrapped tokens (shares)
    /// Note: Apply division at the end as it results in the removal of 'decimal 0's
    function convertToShares(uint assets) public view returns(uint shares){
        return (assets * exRate) / 1e27;
    }

    /// @notice calculate how much DAI user should get based on exchange rate
    /// @dev exRate(27 dp precision) | both assets and shares are 18 dp precision
    /// @param shares Amount of wrapped tokens (shares)to be converted to underlying tokens (assets) 
    /// Note: Apply division at the end as it results in the removal of 'decimal 0's
    function convertToAssets(uint shares) public view returns(uint assets){
        return (shares * 1e27) / exRate;
    }
    
    /// Note that any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in share price
    function previewDeposit(uint assets) public view returns(uint shares) {
        return convertToShares(assets);
    }

    /// Note that any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in share price
    function previewWithdraw(uint assets) public view returns(uint shares) {
        return convertToShares(assets);
    }
    

}