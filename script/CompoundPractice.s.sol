// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {WhitePaperInterestRateModel} from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {Unitroller} from "compound-protocol/contracts/Unitroller.sol";
import {ComptrollerG7} from "compound-protocol/contracts/ComptrollerG7.sol";
import {SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";
import {CErc20Delegate} from "compound-protocol/contracts/CErc20Delegate.sol";
import {FPToken} from "../src/FPToken.sol";

contract CompoundPractice is Script {
    FPToken token;
    // Storage for the comptroller is at this address
    Unitroller unitroller;
    // interact with cToken, oracle, interestModel
    ComptrollerG7 comptroller;
    // calculate assets value
    SimplePriceOracle oracle;
    // calculate interest rate
    WhitePaperInterestRateModel interestModel;
    // deposite, withdraw, calculate interest, interact with unitroller
    CErc20Delegate delegate;
    // proxy of CERC20Delegate
    CErc20Delegator delegator;

    function run() public {
        vm.startBroadcast();
        // deploy an underlying token and decimals is 18
        token = new FPToken();
        // deploy Unitroller
        unitroller = new Unitroller();
        comptroller = new ComptrollerG7();
        // use SimplePriceOracle as oracle
        oracle = new SimplePriceOracle();
        comptroller._setPriceOracle(oracle);
        // use WhitePaperInterestRateModel as interestModel
        // borrow and loan rates are 0
        interestModel = new WhitePaperInterestRateModel(0,0);
        // use CERC20Delegate as delegate
        delegate = new CErc20Delegate();

        // use CERC20Delegator as delegator and set exchange rate to 1
        /**
        * @notice Construct a new money market
        * @param underlying_ The address of the underlying asset
        * @param comptroller_ The address of the Comptroller
        * @param interestRateModel_ The address of the interest rate model
        * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
        * @param name_ ERC-20 name of this token
        * @param symbol_ ERC-20 symbol of this token
        * @param decimals_ ERC-20 decimal precision of this token
        * @param admin_ Address of the administrator of this token
        * @param implementation_ The address of the implementation the contract delegates to
        * @param becomeImplementationData The encoded args for becomeImplementation
        */

        delegator = new CErc20Delegator(
            address(token),
            comptroller, 
            interestModel, 
            1e18, 
            "cFPToken",
            "cFPT", 
            18,
            //my MetaMask Mainnet address
            payable(0xF6f419908e7349d80Bb5400bB5eA5Db7B6AaEAAc), 
            address(delegate),
            new bytes(0)); 

        vm.stopBroadcast();
    }
}
