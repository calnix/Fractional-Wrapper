// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "yield-utils-v2/contracts/mocks/ERC20Mock.sol";
import "yield-utils-v2/contracts/token/IERC20.sol";

contract YearnVaultMock is ERC20Mock {
    
    ///@notice ERC20 interface specifying contract functions
    ///@dev For constant variables, the value has to be fixed at compile-time, while for immutable, it can still be assigned at construction time.
    IERC20 public immutable token;    
    
    uint pricePerFullShare;

    ///@notice Creates a new wrapper token for a specified token 
    ///@dev Token will have 18 decimal places as ERC20Mock inherits from ERC20Permit
    ///@param token_ Address of FrationaWrapper contract
    ///@param tokenName Name of Yearn Vault tokens
    ///@param tokenSymbol Symbol of Yearn Vault tokens
    constructor(IERC20 token_, string memory tokenName, string memory tokenSymbol) ERC20Mock(tokenName, tokenSymbol) {
        token = token_;
    }
    
    /// @notice User to deposit underlying DAI tokens
    /// @dev Expect deposit to revert if transferFrom fails
    /// @param amount The amount of underlying tokens sent by FractionalizedWrapper 
    function deposit(uint amount) public {
        // do math -> how much yvTokens to send for DAI.
        amount / pricePerFullShare;

    }


//- It will also need a function to check the price of one share. (look up that function name in the actual Yearn Vault contracts)
//- In the mocked contract, the price returned by this function will be stored in a state var which can be easily set in your tests.

    function withdraw() external {}

    function getPricePerFullShare() external view returns (uint) {
        return pricePerFullShare;
    }

    function setPricePerFullShare(uint sharePrice_) public {
        sharePrice = sharePrice_;
    }


}


// function to check the price of one share. (look up that function name in the actual Yearn Vault contracts)
// https://github.com/yearn/yearn-protocol/blob/mainnet/contracts/vaults/yDelegatedVault.sol
//  getPricePerFullShare [getReservePrice, getUnderlyingPrice,]

/*
    function getPricePerFullShare() public view returns (uint) {
        return balance().mul(1e18).div(totalSupply());
    }

*/