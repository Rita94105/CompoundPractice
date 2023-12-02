// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {WhitePaperInterestRateModel} from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {Unitroller} from "compound-protocol/contracts/Unitroller.sol";
import {Comptroller} from "compound-protocol/contracts/Comptroller.sol";
import {SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";
import {CErc20Delegate} from "compound-protocol/contracts/CErc20Delegate.sol";
import {FPToken} from "../src/FPToken.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";

contract CompoundPractice is Script {
    // Storage for the comptroller is at this address
    Unitroller unitroller;
    // interact with cToken, oracle, interestModel
    Comptroller comptroller;
    // calculate assets value
    SimplePriceOracle oracle;
    // calculate interest rate
    WhitePaperInterestRateModel interestModel;
    // proxy of CERC20Delegator
    CErc20Delegate delegate;
    // deposite, withdraw, calculate interest, interact with unitroller
    CErc20Delegator[] delegators;
    // FPTokens
    address[] tokens;

    function run() public {
        vm.startBroadcast();
        //my MetaMask Mainnet address
        FPToken token = new FPToken("FPToken1","T1");
        tokens.push(address(token));
        _deploy(0xF6f419908e7349d80Bb5400bB5eA5Db7B6AaEAAc,tokens);
        vm.stopBroadcast();
    }

    function _deploy(address _admin,address[] memory _tokens) internal {
        // deploy Unitroller
        unitroller = new Unitroller();
        // deploy Comptroller
        comptroller = new Comptroller();
        // use SimplePriceOracle as oracle
        oracle = new SimplePriceOracle();
        // set oracle to comptroller
        comptroller._setPriceOracle(oracle);
        // set comptroller to unitroller
        unitroller._setPendingImplementation(address(comptroller));
        // set unitroller to comptroller
        comptroller._become(unitroller);
        // use WhitePaperInterestRateModel as interestModel
        // borrow and loan rates are 0
        interestModel = new WhitePaperInterestRateModel(0,0);
        // use CERC20Delegate as delegate
        delegate = new CErc20Delegate();
        // set delegators[] length
        delegators = new CErc20Delegator[](_tokens.length);

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
        for (uint i = 0; i < tokens.length; i++) {
            delegators[i] = new CErc20Delegator(
                tokens[i],
                comptroller, 
                interestModel, 
                1e18, 
                string(abi.encodePacked("cFPToken", (i+1))),
                string(abi.encodePacked("cT", (i+1))),
                18,
                payable(_admin), 
                address(delegate),
                new bytes(0)); 
            comptroller._supportMarket(CToken(address(delegators[i])));
        }
    }
}