// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    address public tokenA;
    address public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    constructor(address tokenA_, address tokenB_)
        ERC20("Simple", "SMP"){
            require(tokenA_.code.length > 0, "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
            require(tokenB_.code.length > 0, "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
            require(tokenA_ != tokenB_, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");

            if(tokenA_ < tokenB_){
                tokenA = tokenA_;
                tokenB = tokenB_;
            } else {
                tokenA = tokenB_;
                tokenB = tokenA_;
            }
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external override returns (uint256 amountOut_){
        require(tokenIn == tokenA || tokenIn == tokenB, "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == tokenA || tokenOut == tokenB, "SimpleSwap: INVALID_TOKEN_OUT");
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        uint256 amountOut;
        if(tokenIn == tokenA && tokenOut == tokenB) {
            // reserveA * reserveB / (reserveA + amountIn) is integer division
            // the result might be smaller than actual value
            // which further cause amountOut larger than actual value
            // If amountOut is larger than actual value, user swap out more token than expected
            // Liquidity(K) will decrease

            // Solution here is to add one more digit precision to amountOut and discard it anyway
            // Another solution is to add 1 to the integer divsion result if there exist remainder
            
            amountOut = reserveB * 10 - reserveA * reserveB * 10 / (reserveA + amountIn);
            amountOut /= 10;
            ERC20(tokenA).transferFrom(msg.sender, address(this), amountIn);
            ERC20(tokenB).transfer(msg.sender, amountOut);
            reserveA += amountIn;
            reserveB -= amountOut;
            emit Swap(msg.sender, tokenA, tokenB, amountIn, amountOut);
            amountOut_ = amountOut;
        } else if(tokenIn == tokenB && tokenOut == tokenA) {
            amountOut = reserveA * 10- reserveA * reserveB * 10 / (reserveB + amountIn);
            amountOut /= 10;
            ERC20(tokenA).transfer(msg.sender, amountOut);
            ERC20(tokenB).transferFrom(msg.sender, address(this), amountIn);
            reserveB += amountIn;
            reserveA -= amountOut;
            emit Swap(msg.sender, tokenB, tokenA, amountIn, amountOut);
            amountOut_ = amountOut;
        }
    }

    function addLiquidity(uint256 amountAIn, uint256 amountBIn)
        external
        override
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        ){
        require(amountAIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(amountBIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");


        if(reserveA == 0 && reserveB == 0) {
            amountA = amountAIn;
            amountB = amountBIn;
            reserveA = amountA;
            reserveB = amountB;

            ERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
            ERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

            liquidity = Math.sqrt(amountA * amountB); 
            _mint(msg.sender, liquidity);
            emit AddLiquidity(msg.sender, amountA, amountB, liquidity);
        } else {
            uint256 expectB = amountAIn * reserveB / reserveA;
            if(expectB < amountBIn) {
                amountA = amountAIn;
                amountB = expectB;
            } else {
                amountA = amountBIn * reserveA / reserveB;
                amountB = amountBIn;
            }

            reserveA += amountA;
            reserveB += amountB;

            ERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
            ERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
            liquidity = Math.sqrt(amountA * amountB); 
            _mint(msg.sender, liquidity);
            emit AddLiquidity(msg.sender, amountA, amountB, liquidity);
        }
    }

    function removeLiquidity(uint256 liquidity) 
        external
        override
        returns (
            uint256 amountA,
            uint256 amountB
        ){
        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");
        uint256 totalSupply = totalSupply();
        amountA = liquidity * reserveA / totalSupply;
        amountB = liquidity * reserveB / totalSupply;
        _transfer(msg.sender, address(this), liquidity);
        _burn(address(this), liquidity);
        ERC20(tokenA).transfer(msg.sender, amountA);
        ERC20(tokenB).transfer(msg.sender, amountB);
        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity);
        reserveA -= amountA;
        reserveB -= amountB;
    }

    function getReserves() 
        external
        view 
        override
        returns (
            uint256 reserveA_,
            uint256 reserveB_
        ){
        reserveA_ = reserveA;
        reserveB_ = reserveB;
    }

    function getTokenA() external view override returns (address tokenA_) {
        tokenA_ = tokenA;
    }

    function getTokenB() external view override returns (address tokenB_) {
        tokenB_ = tokenB;
    }
}
