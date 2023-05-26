// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Callee } from "v2-core/interfaces/IUniswapV2Callee.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router01 } from "v2-periphery/interfaces/IUniswapV2Router01.sol";
import { IWETH } from "v2-periphery/interfaces/IWETH.sol";
import { IFakeLendingProtocol } from "./interfaces/IFakeLendingProtocol.sol";

// This is liquidator contrac for testing,
// all you need to implement is flash swap from uniswap pool and call lending protocol liquidate function in uniswapV2Call
// lending protocol liquidate rule can be found in FakeLendingProtocol.sol
contract Liquidator is IUniswapV2Callee, Ownable {
    struct CallbackData {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
    }

    address internal immutable _FAKE_LENDING_PROTOCOL;
    address internal immutable _UNISWAP_ROUTER;
    address internal immutable _UNISWAP_FACTORY;
    address internal immutable _WETH9;
    uint256 internal constant _MINIMUM_PROFIT = 0.01 ether;

    constructor(address lendingProtocol, address uniswapRouter, address uniswapFactory) {
        _FAKE_LENDING_PROTOCOL = lendingProtocol;
        _UNISWAP_ROUTER = uniswapRouter;
        _UNISWAP_FACTORY = uniswapFactory;
        _WETH9 = IUniswapV2Router01(uniswapRouter).WETH();
    }

    //
    // EXTERNAL NON-VIEW ONLY OWNER
    //

    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{ value: address(this).balance }("");
        require(success, "Withdraw failed");
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(msg.sender, amount), "Withdraw failed");
    }

    //
    // EXTERNAL NON-VIEW
    //

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
        require(sender == address(this), "Sender must be this contract");
        require(amount0 > 0 || amount1 > 0, "amount0 or amount1 must be greater than 0");

        // 4. decode callback data
        CallbackData memory callbackData;
        callbackData = abi.decode(data, (CallbackData));
        // 5. call liquidate
        IERC20(callbackData.tokenOut).approve(_FAKE_LENDING_PROTOCOL, callbackData.amountOut);
        IFakeLendingProtocol(_FAKE_LENDING_PROTOCOL).liquidatePosition();
        // 6. deposit ETH to WETH9, because we will get ETH from lending protocol
        IWETH(_WETH9).deposit{value: callbackData.amountIn}();
        // 7. repay WETH to uniswap pool
        IWETH(_WETH9).transfer(msg.sender, callbackData.amountIn);
        // check profit
        require(address(this).balance >= _MINIMUM_PROFIT, "Profit must be greater than 0.01 ether");
    }

    // we use single hop path for testing
    function liquidate(address[] calldata path, uint256 amountOut) external {
        require(amountOut > 0, "AmountOut must be greater than 0");
        // 1. get uniswap pool address
        address pair =  IUniswapV2Factory(_UNISWAP_FACTORY).getPair(path[0], path[1]); 
        // 2. calculate repay amount
        uint256 wethAmount = IUniswapV2Router01(_UNISWAP_ROUTER).getAmountsIn(amountOut, path)[0];
        // 3. flash swap from uniswap pool
        CallbackData memory callbackData;
        callbackData.amountIn = wethAmount; // wethIn
        callbackData.amountOut = amountOut; // usdcOut 80
        callbackData.tokenIn = path[0]; // weth
        callbackData.tokenOut = path[1]; // usdc

        IUniswapV2Pair(pair).swap(0, amountOut, address(this), abi.encode(callbackData)); // swap(weth, usdc, to, data)
    }

    receive() external payable {}
}