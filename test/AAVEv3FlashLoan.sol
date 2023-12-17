// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
  IFlashLoanSimpleReceiver,
  IPoolAddressesProvider,
  IPool
} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {WhitePaperInterestRateModel} from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {Unitroller} from "compound-protocol/contracts/Unitroller.sol";
import {Comptroller} from "compound-protocol/contracts/Comptroller.sol";
import {SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";
import {CErc20Delegate} from "compound-protocol/contracts/CErc20Delegate.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";
import {FlashLoan} from "../src/FlashLoan.sol";



contract AAVEv3FlashLoan is Test{
    address admin = makeAddr("admin");
    // borrow money
    address user1 = makeAddr("user1");
    // do liquidation
    address user2 = makeAddr("user2");
    // deposit tokens to the pool
    address user3 = makeAddr("user3");

    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

    address[] tokens;
    Unitroller unitroller;
    Comptroller comptroller;
    SimplePriceOracle oracle;
    WhitePaperInterestRateModel interestModel;
    CErc20Delegate delegate;
    CErc20Delegator cUSDC;
    CErc20Delegator cUNI;

    uint initUSDC = 5000*1e6;
    uint initUNI = 1000*1e18;

    function setUp() public {   
        tokens.push(USDC);
        tokens.push(UNI);

        uint256 forkId = vm.createFork(vm.envString("MAINNET_RPC_URL"),  17_465_000);
        vm.selectFork(forkId);

        vm.startPrank(admin);
        unitroller = new Unitroller();
        comptroller = new Comptroller();
        oracle = new SimplePriceOracle();
        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        Comptroller(address(unitroller))._setPriceOracle(oracle);
        interestModel = new WhitePaperInterestRateModel(0,0);
        delegate = new CErc20Delegate();

        cUSDC = new CErc20Delegator(
            USDC,
            Comptroller(address(unitroller)),
            interestModel,
            1e6,
            "Compound USDC",
            "cUSDC",
            18,
            payable(admin),
            address(delegate),
            new  bytes(0)
        );
        Comptroller(address(unitroller))._supportMarket(CToken(address(cUSDC)));
        cUNI = new CErc20Delegator(
            UNI,
            Comptroller(address(unitroller)),
            interestModel,
            1e18,
            "Compound UNI",
            "cUNI",
            18,
            payable(admin),
            address(delegate),
            new  bytes(0)
        );
        Comptroller(address(unitroller))._supportMarket(CToken(address(cUNI)));
        // set Close Factor = 50%
        Comptroller(address(unitroller))._setCloseFactor(0.5e18);
        // set Incentive = 1.08%
        Comptroller(address(unitroller))._setLiquidationIncentive(1.08*1e18);
        // set USDC = 1 USD
        oracle.setUnderlyingPrice(CToken(address(cUSDC)),1e30);
        // set UNI = 5 USD
        oracle.setUnderlyingPrice(CToken(address(cUNI)),5e18);
        // set UNI collateral factor = 50%
        Comptroller(address(unitroller))._setCollateralFactor(CToken(address(cUNI)),5e17);
        vm.stopPrank();

        _depositLendingPool();
    }

    function testLiquidate() public{

        // user1 use 1000 ether UNI to borrow 2500 ether USDC
        deal(UNI,user1,initUNI);
        vm.startPrank(user1);
        _mintCToken(UNI,cUNI,initUNI);
        _borrowToken(cUNI,cUSDC,2500*1e6);
        vm.stopPrank();

        // UNI price from 5 USD to 4 USD
        vm.startPrank(admin);
        oracle.setUnderlyingPrice(CToken(address(cUNI)),4e18);
        vm.stopPrank();

        // borrow money from AAVE flashloan to liqudate user1
        vm.startPrank(user2);
        // check user1 can be liquidated or not
        (uint error, uint liquidity, uint shortfall) = Comptroller(address(unitroller)).getAccountLiquidity(user1);
        require(error == 0,"error");
        require(shortfall > 0,"shortfall should be 0 or would be liquidated");

        _flashloantoLiquidate(cUSDC,cUNI,USDC,UNI,user1);

        vm.stopPrank();
        
        console2.log("user2 USDC balance",IERC20(USDC).balanceOf(user2));
        assertGe(IERC20(USDC).balanceOf(user2), 63*1e6,"user2 get more than 63 USDC");
    }

    function _depositLendingPool() internal{
        deal(USDC,user3,initUSDC);
        vm.startPrank(user3);
        IERC20(USDC).approve(address(cUSDC),type(uint256).max);
        cUSDC.mint(initUSDC);
        vm.stopPrank();
    }

    function _mintCToken(address token,CErc20Delegator ctoken, uint amount) internal{
        IERC20(token).approve(address(ctoken),type(uint256).max);
        ctoken.mint(amount);
    }

    function _borrowToken(CErc20Delegator collateral, CErc20Delegator borrow, uint amount) internal{
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(collateral);
        Comptroller(address(unitroller)).enterMarkets(cTokens);
        borrow.borrow(amount);
    }

    function _flashloantoLiquidate(CErc20Delegator cUSDC,CErc20Delegator cUNI, address USDC, address UNI, address user1) internal{
        uint borrowBalance = cUSDC.borrowBalanceStored(user1);
        // close factor is 50%
        uint maxClose = borrowBalance / 2;
        FlashLoan fl = new FlashLoan();
        bytes memory data = abi.encode(cUSDC,cUNI,USDC,UNI,user1);
        fl.execute(USDC,maxClose,data);
        fl.withdraw(USDC);
    }
}