# Objective
Fixed-point math

Users can send some (underlying token), to a contract that also is an ERC20(Fractional Wrapper)
FractionalWrapper is just a wrapper around a Yearn Vault token.



# In-Flow
1. User deposits collateral to FractionalizedWrapper.
2. FractionalWrapper will immediately handover the collateral into the YearnVault.
(user -> FractionalizedWrapper -> YearnVault)
(collateral -> collateral -> collateral:recieved by YearnVault)

# Out-flow 
(Upon receiving collateral)
1. Vault sends yvCollateral to FractionalizedVault
2. FractionalizedVault sends FractionalWrapper shares to user, where amt(Wrappershares == yvCollateral)

User sent collateral.
User received Wrappershares.
User can burn Wrappershares for collateral. (PnL depends on price of yvCollateral).


# Contracts
1. Collateral Token
2. Fractional Wrapper
3. Yearn Vault (use Mock)

1. Mock the YearnVault token. 
- It needs a deposit and withdraw function. 
- It will also need a function to check the price of one share. (look up that function name in the actual Yearn Vault contracts)
- In the mocked contract, the price returned by this function will be stored in a state var which can be easily set in your tests.
- This number is in the range of [0.0, 1000000000000000000.0), and available in increments of 10**-27. 
-- This type of number is commonly referred to as a ray.






# Deployment 
Node provider: Alchemy
Target network: Optimism-Kovan



User sends QTM to (=> FracWrapper) Yearn Vault.
    Qty of yvQTM received is dependent on sharePrice. 
    100 QTM sent, yvQTM received =  QTM/sharePrice

yvQTM sent to Vault.
Vault sents eq.amt of Shares to User.

User can burn shares for QTM. (amt depends on price).



# New one
Users can send a pre-specified erc-20 token (underlying) to an ERC20 contract(Fractional Wrapper).

The Fractional Wrapper contract issues a number of Wrapper tokens to the sender,
equal to the deposit multiplied by a fractional number, called exchange rate, set by the contract owner. 

This number is in the range of [0, 1000000000000000000], and available in increments of 10**-27. (ray).

At any point, a holder of Wrapper tokens can burn them to recover an amount of underlying equal to the amount of Wrapper tokens burned, divided by the exchange rate.

1. User sends DAI to FWrapper.
2. User receives wDAI(wDAI = DAI * ex_rate) | ex_rate is fractional number.  
3. Exchange rate set by FWrapper owner.
4. Ex_rate is 10**18 with 10**27 precision
    - A ray is a decimal number with 27 digits of precision that is being represented as an integer. 100...00 (27 zeroes)


5. User can liquidate and get back underlying DAI, by burning wDAI.
---> dai_qty = wDAI/ex_rate

## Contracts
1. DAI token - underlying
2. Fwrapper - "vault w/ ex_rate" 

Both contracts are ERC20Mock, to issue tokens. 
Fwrapper must conform to ERC4626 specification.
- implementation of convert* and preview* will be identical in this case (no need to calculate some time-weighted average for convert*).


deposit(asset)*ex_rate = shares