// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {CompoundPractice} from "../script/CompoundPractice.s.sol";
import {FPToken} from "../src/FPToken.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";
import {Comptroller} from "compound-protocol/contracts/Comptroller.sol";

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
        // original value * CollateralFactor = borrowable value
        Comptroller(address(unitroller))._setCollateralFactor(CToken(address(delegators[1])),5e17);
        // LiquidationIncentive = get profit from liquidation (108%)
        Comptroller(address(unitroller))._setLiquidationIncentive(1.08e18);
        // maximum value that others can be liquidated
        Comptroller(address(unitroller))._setCloseFactor(0.5e18);
        // protocol Seize Share = protocol profit from liquidation
        vm.stopPrank();
    }

    function testMintAndRedeem() public {
        deal(address(T1),user1,initBalance);
        vm.startPrank(user1);
        // approve 100 T1 to delegator[0]
        T1.approve(address(delegators[0]),type(uint256).max);
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
        
        deal (address(T2),user1,1 ether);
        vm.startPrank(user1);
        // user1 use 1 ether T2 to mint cT2
        _mintcToken();
        // use 1 ether cT2 to borrow 50 ether T1
        _borrow();
        assertEq(T1.balanceOf(user1),50 ether);

        // user1 repay 25 ether T1
        _repay();
        assertEq(T1.balanceOf(user1),25 ether);

        vm.stopPrank();
    }

    function testCollateralFactortoLiquidate() public{
        // user3 deposit 100 ether T1 to the pool
        _depositPool();
        
        deal (address(T2),user1,1 ether);
        vm.startPrank(user1);
        // user1 use 1 ether T2 to mint cT2
        _mintcToken();
        // use 1 ether cT2 to borrow 50 ether T1
        _borrow();
        vm.stopPrank();

        vm.startPrank(admin);
        // set close factor that user2 can liquidate user1
        // modify T2 collateral factor from 50% to 30%
        Comptroller(address(unitroller))._setCollateralFactor(CToken(address(delegators[1])),3e17);
        vm.stopPrank();

        // gas fee
        deal(address(T1),user2,initBalance);
        vm.startPrank(user2);
        // liquidate user1
        _liquidate();
        vm.stopPrank();
    }

    function testOracletoLiquidate() public{
        // user3 deposit 100 ether T1 to the pool
        _depositPool();
        
        deal (address(T2),user1,1 ether);
        vm.startPrank(user1);
        // user1 use 1 ether T2 to mint cT2
        _mintcToken();
        // use 1 ether cT2 to borrow 50 ether T1
        _borrow();
        vm.stopPrank();

        vm.startPrank(admin);
        // set T2 price that user2 can liquidate user1
        // modify T2 price from 100USD to 90USD
        oracle.setUnderlyingPrice(CToken(address(delegators[1])),9e19);
        vm.stopPrank();

        // gas fee
        deal(address(T1),user2,initBalance);
        vm.startPrank(user2);
        // liquidate user1
        _liquidate();
        vm.stopPrank();
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

    function _mintcToken() internal{
        // approve 1 ether T2 to delegator[1]
        T2.approve(address(delegators[1]),1 ether);
        // mint 1 ether cT2
        delegators[1].mint(1 ether);
        assertEq(delegators[1].balanceOf(user1),1 ether);
    }

    function _borrow() internal{
        // cT2 enter market
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(delegators[1]);
        Comptroller(address(unitroller)).enterMarkets(cTokens);
        delegators[0].borrow(50 ether);
    }

    function _repay() internal{
        // approve 25 ether T1 to delegator[0]
        T1.approve(address(delegators[0]),type(uint256).max);
        // repay 25 ether T1
        delegators[0].repayBorrow(25 ether);
    }

    function _liquidate() internal{
        //user2 calculate user1 can be liquidated or not
        (uint error, uint liquidity, uint shortfall) = Comptroller(address(unitroller)).getAccountLiquidity(user1);
        
        require(error == 0,"error");
        require(shortfall > 0,"shortfall should be 0 or would be liquidated");
        
        uint borrowBalance = delegators[0].borrowBalanceStored(user1);
        // close factor is 50%
        uint maxClose = borrowBalance / 2;
        
        // approve max T1 to cT1
        T1.approve(address(delegators[0]),type(uint256).max);
        // user2 liquidate user1
        delegators[0].liquidateBorrow(user1,maxClose,delegators[1]);

        assertEq(T1.balanceOf(user2),initBalance - maxClose);
        assertEq(delegators[0].borrowBalanceStored(user1),borrowBalance - maxClose);

        // calculate the profit of liquidation
        (, uint256 seizes) = Comptroller(address(unitroller)).liquidateCalculateSeizeTokens(
            address(delegators[0]), address(delegators[1]), maxClose);
        assertEq(delegators[1].balanceOf(user2),seizes*(1e18 - 2.8e16)/1e18);
    }
}
