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
    IERC20 public immutable underlying;    
    
    /// @notice Emit event when ERC20 tokens are deposited into Fractionalized Wrapper
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    
    /// @notice Emit event when ERC20 tokens are withdrawn from Fractionalized Wrapper
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);


    ///@notice Creates a new wrapper token for a specified token 
    ///@dev Token will have 18 decimal places as ERC20Mock inherits from ERC20Permit
    ///@param underlying_ Address of underlying ERC20 token (e.g. DAI)
    ///@param tokenName Name of FractionalWrapper tokens 
    ///@param tokenSymbol Symbol of FractionalWrapper tokens (e.g. yvDAI)
    constructor(IERC20 underlying_, string memory tokenName, string memory tokenSymbol) ERC20Mock(tokenName, tokenSymbol) {
        underlying = underlying_;
    }


    /// @notice User to deposit underlying tokens for FractionalWrapper tokens
    /// @dev Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens
    /// @param assets The amount of underlying tokens to deposit
    /// @param receiver Address of receiver of Fractional Wrapper shares
    function deposit(uint256 assets, address receiver) external returns(uint256 shares) {       
        receiver = msg.sender;
        shares = convertToShares(assets);

        //transfer DAI from user
        bool success = underlying.transferFrom(receiver, address(this), assets);
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
    function withdraw(uint256 assets, address receiver, address owner) external returns(uint256 shares) {
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
        bool success = underlying.transfer(receiver, assets);
        require(success, "Transfer failed!"); 
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @dev Burns shares from owner and sends assets of underlying tokens to receiver; based on the exchange rate.
    /// @param shares The amount of wrapped tokens to redeem for underlying tokens (assets)
    /// @param receiver Address of receiver of underlying tokens - DAI
    /// @param owner Address of owner of Fractional Wrapper shares - yvDAI
    function redeem(uint256 shares, address receiver, address owner) external returns(uint256 assets) {
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
        bool success = underlying.transfer(receiver, assets);
        require(success, "Transfer failed!"); 
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }



    /// @notice Only the owner can call to modify exchange rate
    /// @dev Exchange rate is of 1e27 precision | Ex-rate: 1 DAI/yvDAI = 0.5 -> 1 DAI gets you 1/2 yvDAI
    /// @param exRate_ New exchange rate
    function setExchangeRate(uint256 exRate_) external onlyOwner {
        exRate = exRate_;
    }

    /// @notice calculate how much yvDAI user should get based on exchange rate
    /// @dev exRate(27 dp precision) | both assets and shares are 18 dp precision
    /// @param assets Amount of underlying tokens (assets) to be converted to wrapped tokens (shares)
    /// Note: Apply division at the end as it results in the removal of 'decimal 0's
    function convertToShares(uint256 assets) public view returns(uint256 shares){
        return (assets * exRate) / 1e27;
    }

    /// @notice calculate how much DAI user should get based on exchange rate
    /// @dev exRate(27 dp precision) | both assets and shares are 18 dp precision
    /// @param shares Amount of wrapped tokens (shares)to be converted to underlying tokens (assets) 
    /// Note: Apply division at the end as it results in the removal of 'decimal 0's
    function convertToAssets(uint256 shares) public view returns(uint256 assets){
        return (shares * 1e27) / exRate;
    }

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given current on-chain conditions
    /// @dev Any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage
    /// @param assets Amoutn of assets to deposit
    function previewDeposit(uint256 assets) external view returns(uint256 shares) {
        return convertToShares(assets);
    }


    /// @notice Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block, given current on-chain conditions.
    /// @dev Any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage
    /// @param assets Amoutn of assets to withdraw
    function previewWithdraw(uint256 assets) external view returns(uint256 shares) {
        shares = convertToShares(assets);
    }

   
    ///Note: newly added

    /// @notice Function returns contract address of underlying token utilized by the vault (e.g. DAI)
    /// @dev MUST be an ERC-20 token contract 
    function asset() external view returns(address assetTokenAddress){
        assetTokenAddress = address(underlying);
    }

    /// @notice Returns total amount of the underlying asset (e.g. DAI) that is “managed” by Vault.
    /// @dev SHOULD include any compounding that occurs from yield, account for any fees that are charged against assets in the Vault
    function totalAssets() external view returns(uint256 totalManagedAssets) {
        totalManagedAssets = underlying.balanceOf(address(this));
    }


    ///@notice Maximum amount of the underlying asset that can be deposited into the Vault by the receiver, through a deposit call.
    ///@dev Return the maximum amount of assets that would be allowed for deposit by receiver, and not cause revert
    ///Note: In this Vault implementation there are no restrictions in minting supply, therefore, no deposit restrictions. 
    ///Note: Consequently, maxAssets = type(uint256).max for all users => therefore we drop the 'receiver' param as specified in EIP4626
    ///Note: To allow for this to be overwritten as per EIP4626, function is set to virtual
    function maxDeposit() external view virtual returns (uint256 maxAssets) {
        maxAssets = type(uint256).max;
    }
    
    ///@notice Maximum amount of shares that can be minted from the Vault for the receiver, through a mint call.
    ///@dev MUST return the maximum amount of shares mint would allow to be deposited to receiver+
    ///Note: In this Vault implementation there are no restrictions in minting supply
    ///Note: Consequently, maxShares = type(uint256).max for all users => therefore we drop the 'receiver' param as specified in EIP4626
    ///Note: To allow for this to be overwritten as per EIP4626, function is set to virtual
    function maxMint() external view virtual returns(uint maxShares) {
        maxShares = type(uint256).max;
    }

    ///@notice Allows a user to simulate the effects of their mint at the current block, given current on-chain conditions.
    ///@dev Return as close to and no fewer than the exact amount of assets that would be deposited in a mint call in the same transaction
    ///@param shares Amount of shares to be minted
    function previewMint(uint256 shares) external view returns (uint256 assets) {
        assets = convertToAssets(shares);
    }


    ///@notice Mints Vault shares to receiver based on the deposited amount of underlying tokens
    ///@param shares Amount of shares to be minted
    ///@param receiver Address of receiver
    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        assets = convertToAssets(shares); 
        bool sent = underlying.transferFrom(msg.sender, address(this), assets);
        require(sent, "Transfer failed!"); 

        bool success = _mint(receiver, shares);
        require(success, "Mint failed!"); 
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    ///@notice Maximum amount of the underlying asset that can be withdrawn from the owner balance in the Vault, through a withdraw call.
    ///@param owner Address of owner of assets
    function maxWithdraw(address owner) external view returns(uint256 maxAssets) {
        maxAssets = convertToAssets(_balanceOf[owner]);
    }


    ///@notice Maximum amount of Vault shares that can be redeemed from the owner balance in the Vault, through a redeem call.
    ///@param owner Address of owner of assets
    function maxRedeem(address owner) external view returns(uint256 maxShares) {
        maxShares = _balanceOf[owner];
    }

    ///@notice Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block, given current on-chain conditions.
    ///@param shares Amount of shares to be redeemed
    function previewRedeem(uint256 shares) external view returns(uint256 assets) {
        assets = convertToAssets(shares);
    }
}