pragma solidity 0.8.19;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import {
  IFlashLoanSimpleReceiver,
  IPoolAddressesProvider,
  IPool
} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";

import { ISwapRouter } from "v3-periphery/interfaces/ISwapRouter.sol";
import { Comptroller } from "compound-protocol/contracts/Comptroller.sol";
import { CErc20Delegator } from "compound-protocol/contracts/CErc20Delegator.sol";

contract Liquidator is IFlashLoanSimpleReceiver {
  address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
  address constant POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
  address constant UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

  struct CallbackData {
    address borrowCToken;
    address seizeCToken;
    address borrower;
  }

  function execute(uint256 amount, address borrowCToken, address seizeCToken, address borrower) external {
    CallbackData memory callbackData; 
    callbackData.borrowCToken = borrowCToken;
    callbackData.seizeCToken = seizeCToken;
    callbackData.borrower = borrower;
    bytes memory data = abi.encode(callbackData);
    POOL().flashLoanSimple(
	    address(this),
	    USDC,
      amount,
	    data,
	    0
    );

  }

  function executeOperation(
    address asset,
    uint256 amount,
    uint256 premium,
    address initiator,
    bytes calldata params
  ) override external returns (bool){

    {
      CallbackData memory callbackData = abi.decode(params, (CallbackData));
      CErc20Delegator cDelegatorA = CErc20Delegator(payable(callbackData.borrowCToken));
      CErc20Delegator cDelegatorB = CErc20Delegator(payable(callbackData.seizeCToken)); 
      address borrower = callbackData.borrower;
      // liquidate
      IERC20(USDC).approve(address(cDelegatorA), amount);
      uint success = cDelegatorA.liquidateBorrow(borrower, amount, cDelegatorB);
      require(success == 0, "liquidate fail");
      // redeem UNI
      cDelegatorB.redeem(cDelegatorB.balanceOf(address(this)));
    }

    // swap uni back to usdc
    uint swapAmount = IERC20(UNI).balanceOf(address(this));
    ISwapRouter.ExactInputSingleParams memory swapParams =
    ISwapRouter.ExactInputSingleParams({
      tokenIn: UNI,
      tokenOut: USDC,
      fee: 3000, // 0.3%
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: swapAmount,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0
    });
    IERC20(UNI).approve(UNISWAP_ROUTER, swapAmount);
    uint256 amountOut = ISwapRouter(UNISWAP_ROUTER).exactInputSingle(swapParams);

    // repay usdc
    IERC20(asset).approve(msg.sender, amount + premium);
    return true;
  }

  function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
    return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
  }

  function POOL() public view returns (IPool) {
    return IPool(ADDRESSES_PROVIDER().getPool());
  }
}
