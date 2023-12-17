pragma solidity 0.8.20;

import {console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
  IFlashLoanSimpleReceiver,
  IPoolAddressesProvider,
  IPool
} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";

contract FlashLoan is IFlashLoanSimpleReceiver{
    address POOL_ADDRESSES_PROVIDER = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address owner;

    constructor() {
        owner = msg.sender;
    }

    function execute(address token, uint amount, bytes calldata data) external {
        address receiverAddress = address(this);
        uint16 referralCode = 0;

        // loan token from Aave
        IPool(POOL_ADDRESSES_PROVIDER).flashLoanSimple(
            receiverAddress,
            token,
            amount,
            data,
            referralCode
        );
    }

    function  executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
        )  external override returns (bool) {
        
        require(initiator == address(this), "initiator mismatch");
        uint256 totalAmount = amount + premium;
        require(msg.sender == POOL_ADDRESSES_PROVIDER, "sender mismatch");
        (CErc20Delegator cUSDC, CErc20Delegator cUNI, address USDC, address UNI, address user) =
            abi.decode(params, (CErc20Delegator, CErc20Delegator, address, address, address));

        IERC20(asset).approve(address(cUSDC), type(uint256).max);
        cUSDC.liquidateBorrow(user, amount, cUNI);
        cUNI.redeem(cUNI.balanceOf(address(this)));
        //console2.log("UNI balance", IERC20(UNI).balanceOf(address(this)));

        // UNI swap to USDC
        IERC20(UNI).approve(swapRouter, type(uint256).max);
        ISwapRouter.ExactInputSingleParams memory swapParams =
        ISwapRouter.ExactInputSingleParams({
            tokenIn: UNI,
            tokenOut: USDC,
            fee: 3000, // 0.3%
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: IERC20(UNI).balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        ISwapRouter(swapRouter).exactInputSingle(swapParams);
        //console2.log("USDC balance", IERC20(USDC).balanceOf(address(this)));
        IERC20(asset).approve(POOL_ADDRESSES_PROVIDER, totalAmount);

        return true;
    }

    function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    }

    function POOL() public view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER().getPool());
    }

    function withdraw(address token) external {
        require(msg.sender == owner);
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }
}