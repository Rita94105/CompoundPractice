## Delpoy a simple Compound contract with Foundry Script

write a Foundry Script to deploy a CErc20Delegator(CErc20Delegators.sol, henceforth referred to as 'cERC20), a Unitroller(Unitroller.sol), and others contracts which are necessary in implementation.

Here are some rules for this Script:

1. The decimals of cERC20 is 18.
2. Deploy an underlying ERC20 token, and its decimals is 18.
3. Implement SimplePriceOracle as Oracle.
4. Implement WhitePaperInterestRateModel as InterestRateModel, and the borrow and loan rates in the model are both 0%.
5. Initate the exchangeRate as 1:1.

### Test

```
forge script script/CompoundPractice.s.sol:CompoundPractice
```

Output

```
(base) rita@RitadeMacBook-Pro CompoundPractice % forge script script/CompoundPractice.s.sol:CompoundPractice
[⠊] Compiling...
No files changed, compilation skipped
Script ran successfully.
Gas used: 10481242

If you wish to simulate on-chain transactions pass a RPC URL.
```

## Implement practical functions in Compound

1. test mint and redeem

- user1 use 100 ether TC1 to mint 100 ether cTC1
- redeem those 100 ether cTC1 to get back 100 ether TC1

2. test borrow and repay

- user1 use 1 ether TC2 to mint cTC2
- use those cTC2 to borrow 50 ether TC1
- repay 25 ether TC1

  Here are some rules for these test:

  1. set TC1 underlying price as 1 USD and TC2 as 100 USD in oracle.
  2. set TC2 collateral factor as 50%.

3. test liquidate by changing collateral factor

- based on scenario 2, adjust TC2's collateral factor from 50% to 30%
- user2 calculate user1 can be liquidated or not
- calculate how much seizes can user2 get from this liquidation
- set liquidation incentive as 108%

4. test liquidate by changing underlying price in Oracle

- based on scenario 2, adjust TC2's underlying price from 100 USD to 90 USD
- user2 calculate user1 can be liquidated or not
- calculate how much seizes can user2 get from this liquidation
- set liquidation incentive as 108%

### Test

```
git clone https://github.com/Rita94105/CompoundPractice.git
cd CompoundPractice
forge install
npm install
forge build
forge test
```

output

```
(base) rita@RitadeMacBook-Pro CompoundPractice % forge test
[⠘] Compiling...
No files changed, compilation skipped

Running 4 tests for test/CompoundPractice.sol:CompoundPracticeTest
[PASS] testBorrowAndRepay() (gas: 903298)
[PASS] testCollateralFactortoLiquidate() (gas: 1269892)
[PASS] testMintAndRedeem() (gas: 348051)
[PASS] testOracletoLiquidate() (gas: 1268158)
Test result: ok. 4 passed; 0 failed; 0 skipped; finished in 38.36ms

Ran 1 test suites: 4 tests passed, 0 failed, 0 skipped (4 total tests)
```

## Implement Compound Loan Protocol and AAVEv3 Flash Loan and Liquidate

- use fork testing in Foundry.
- fork Ethereum mainnet at block 17465000.
- use USDC as Token A and UNI as Token B.
- both decimals of USDC and UNI are 18.
- both exchange rates of USDC and UNI are 1:1.
- set Close Factor as 50%.
- set liquidation incentive as 108%.
- set USDC underlying price as 1 USD and UNI as 5 USD in Oracle.
- set UNI collateral factor as 50%.
- user1 use 1000 UNI to borrow 2500 USDC in Compound v2.
- adjust UNI's underlying price from 5 USD to 4 USD, and user1 will be liquidate by user2.
- user2 use AAVE v3 Flash Loan to loan USDC and liquidate user1.
- user2 will earn 63 USDC approximately in this liquidation.
- the way to swap UNI to USDC

```
// https://docs.uniswap.org/protocol/guides/swaps/single-swaps

ISwapRouter.ExactInputSingleParams memory swapParams =
  ISwapRouter.ExactInputSingleParams({
    tokenIn: UNI_ADDRESS,
    tokenOut: USDC_ADDRESS,
    fee: 3000, // 0.3%
    recipient: address(this),
    deadline: block.timestamp,
    amountIn: uniAmount,
    amountOutMinimum: 0,
    sqrtPriceLimitX96: 0
  });

// The call to `exactInputSingle` executes the swap.
// swap Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564
uint256 amountOut = swapRouter.exactInputSingle(swapParams);
```

## Test

```
git clone https://github.com/Rita94105/CompoundPractice.git
cd CompoundPractice
forge install
npm install
forge build
forge test --mc AAVEv3FlashLoan -vvv
```

Output

```
(base) rita@RitadeMacBook-Pro CompoundPractice % forge test --mc AAVEv3FlashLoan -vvv
[⠑] Compiling...
No files changed, compilation skipped

Running 1 test for test/AAVEv3FlashLoan.sol:AAVEv3FlashLoan
[PASS] testLiquidate() (gas: 2025699)
Logs:
  user2 USDC balance 63638693

Test result: ok. 1 passed; 0 failed; 0 skipped; finished in 2.37s

Ran 1 test suites: 1 tests passed, 0 failed, 0 skipped (1 total tests)
```
