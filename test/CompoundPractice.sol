// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {CompoundPractice} from "../script/CompoundPractice.s.sol";
import {FPToken} from "../src/FPToken.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";

contract CompoundPracticeTest is Test,CompoundPractice {
    address admin = makeAddr("admin");
    // borrow money
    address user1 = makeAddr("user1");
    // do liquidation
    address user2 = makeAddr("user2");
    // deposit tokens to the pool
    address user3 = makeAddr("user3");
    FPToken T1 = new FPToken("FPToken1","T1");
    FPToken T2 = new FPToken("FPToken2","T2");
    uint initBalance = 100 ether;

    function setUp() public {   
        tokens.push(address(T1));
        tokens.push(address(T2));
        vm.startPrank(admin);
        _deploy(admin,tokens);
        // set cT1 1 USD
        oracle.setUnderlyingPrice(CToken(address(delegators[0])),1e18);
        // set cT2 100 USD
        oracle.setUnderlyingPrice(CToken(address(delegators[1])),1e20);
        // set cT2 collateral factor = 50%
        comptroller._setCollateralFactor(CToken(address(delegators[1])),5e17);
        comptroller._setCloseFactor(5e17);
        vm.stopPrank();
    }

    function testMintAndRedeem() public {
        deal(address(T1),user1,initBalance);
        vm.startPrank(user1);
        // approve 100 T1 to delegator[0]
        T1.approve(address(delegators[0]),initBalance);
        // mint 100 cT1
        delegators[0].mint(initBalance);
        // redeem 100 cT1
        delegators[0].redeem(initBalance);
        // redeem 100 T1
        assertEq(T1.balanceOf(user1),initBalance);
        // check cT1 balance = 0
        assertEq(delegators[0].balanceOf(user1),0);
    }

    function testBorrowAndRepay() public {
        // user3 deposit 100 ether T1 to the pool
        _depositPool();
        // user1 use 1 ether T2 to mint cT2
        deal (address(T2),user1,1 ether);
        vm.startPrank(user1);
        // approve 1 ether T2 to delegator[1]
        T2.approve(address(delegators[1]),1 ether);
        // mint 1 ether cT2
        delegators[1].mint(1 ether);
        assertEq(delegators[1].balanceOf(user1),1 ether);

        // use 1 ether cT2 to borrow 50 ether T1
        _borrow();
        assertEq(delegators[0].borrowBalanceStored(user1),50 ether);
        vm.stopPrank();
    }

    function testCollateralFactortoLiquidate() public{
        // user3 deposit 100 ether T1 to the pool
        _depositPool();
        // user1 use 1 ether T2 to mint cT2
        deal (address(T2),user1,1 ether);
        vm.startPrank(user1);
        // approve 1 ether T2 to delegator[1]
        T2.approve(address(delegators[1]),1 ether);
        // mint 1 ether cT2
        delegators[1].mint(1 ether);
        // use 1 ether cT2 to borrow 50 ether T1
        _borrow();

        vm.startPrank(user2);
        T1.approve(address(delegators[0]),type(uint256).max);
        //user2 calculate user1 can be liquidated or not
        (,,uint256 shortfall) = comptroller.getAccountLiquidity(user1);
        require(shortfall > 0,"user1 is safe");
        
    }

    function _depositPool() internal{
        // user3 deposit T1 to the pool
        deal(address(T1),user3,initBalance);
        vm.startPrank(user3);
        // approve 100 T1 to delegator[0]
        T1.approve(address(delegators[0]),initBalance);
        // mint 100 cT1
        delegators[0].mint(initBalance);
        vm.stopPrank();
    }

    function _borrow() internal{
        // cT2 enter market
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(delegators[1]);
        comptroller.enterMarkets(cTokens);
        delegators[0].borrow(50 ether);
    }
}
