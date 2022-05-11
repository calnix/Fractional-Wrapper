// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console2.sol";

import "src/FractionalWrapper.sol";
import "src/DAIToken.sol";


abstract contract StateZero is Test {
        
    DAIToken public dai;
    FractionalWrapper public wrapper;

    address user;
    address stratEngine;
    address deployer;

    uint userTokens;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    function setUp() public virtual {
        dai = new DAIToken();
        vm.label(address(dai), "dai contract");

        wrapper = new FractionalWrapper(IERC20(dai), "yvDAI", "yvDAI");
        vm.label(address(wrapper), "wrapper contract");

        user = address(1);
        vm.label(user, "user");

        stratEngine = address(2);
        vm.label(stratEngine, "Strategy Engine");
        
        deployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
        vm.label(deployer, "deployer");

        // mint and approve
        userTokens = 100 * 1e18;
        dai.mint(user, userTokens);
        vm.prank(user);
        dai.approve(address(wrapper), type(uint).max);
    }
}


contract StateZeroTest is StateZero {
    //cannot withdraw. cannot change exrate. can deposit
    
    //Note: User interacts directly with Wrapper in this scenario; no intermediary parties.
    //  deploy: user is both caller and receiver
    //  withdraw: user is both the owner and receiver

    function testCannotWithdraw(uint amount) public {
        console2.log("User should be unable to withdraw without any deposits made");
        vm.assume(amount > 0 && amount < dai.balanceOf(user));
        vm.expectRevert("ERC20: Insufficient balance");
        vm.prank(user);
        wrapper.withdraw(amount, user, user);
    }
  
    function testUserCannotChangeRate() public {
        console2.log("Only Owner of contract can change exchange rate");
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        wrapper.setExchangeRate(0.5e27);
    }

    function testDeposit() public {
        console2.log("User deposits DAI into Fractional Wrapper");
        uint shares = wrapper.convertToShares(userTokens/2);

        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit Deposit(user, user, userTokens/2, shares);

        wrapper.deposit(userTokens/2, user);
        assertTrue(wrapper.balanceOf(user) == dai.balanceOf(user));
    }
}

abstract contract StateDeposited is StateZero {
    
    function setUp() public override virtual {
        super.setUp();

        //user deposits into wrapper
        vm.prank(user);
        wrapper.deposit(userTokens/2, user);
    }
}


contract StateDepositedTest is StateDeposited {

    function testCannotWithdrawInExcess() public {
        console2.log("User cannot withdraw in excess of what was deposited - burn() will revert");
        vm.prank(user);
        vm.expectRevert("ERC20: Insufficient balance");
        wrapper.withdraw(userTokens, user, user);
    }

    function testWithdraw() public {
        console2.log("User withdraws his deposit");
        uint shares = wrapper.convertToShares(userTokens/2);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(user, user, user, userTokens/2, shares);
        
        vm.prank(user);
        wrapper.withdraw(userTokens/2, user, user);

        assertTrue(wrapper.balanceOf(user) == 0);
        assertTrue(dai.balanceOf(user) == userTokens);
    }

}

abstract contract StateRateChanges is StateDeposited {
    
    function setUp() public override virtual {
        super.setUp();

        // change exchange rate
        wrapper.setExchangeRate(0.5e27);
    }
}

contract StateRateChangesTest is StateRateChanges {
    
    function testCannotWithdrawSameAmount() public {
        console2.log("Rate depreciates: User's shares are redeemable for less than original deposit");
        console2.log("1 yvDAI is redeemable for more DAI");
        
        //Note: if proceed to actually withdraw from wrapper, "ERC20: Insufficient balance", as wrapper does not have additional DAI to payout. 
        uint assets = wrapper.convertToAssets(wrapper.balanceOf(user));
        assertTrue(assets > userTokens/2);
    }
    
    function testCannotDepositSameAmount() public {
        console2.log("Rate depreciates: User's deposit returns fewer shares than before");
        console2.log("1 DAI deposit gets you lesser yvDAI");

        vm.prank(user);
        wrapper.deposit(userTokens/2, user);

        assertTrue(dai.balanceOf(user) == 0);
        assertTrue(wrapper.balanceOf(user) < userTokens);
    }

}