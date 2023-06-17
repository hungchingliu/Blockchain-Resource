// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;
import "forge-std/console.sol";
import "test/helper/CompoundHomeworkForkTestSetUp.sol";
import { Liquidator } from "src/Liquidator.sol";

contract CompoundHomeworkForkTest is CompoundHomeworkForkTestSetUp {
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    uint constant tokenAInitBalance = 2500 * 1e6;
    uint constant tokenBInitBalance = 2500 * 1e18;
    
    function setUp() override public {
        super.setUp();
        // give user1 initial balance
        deal(address(TokenA), user1, tokenAInitBalance);
        deal(address(TokenB), user1, tokenBInitBalance);
    }

    function test_liquidate() public {
        // set oracle price and colaateral factor
        vm.startPrank(admin);
        simplePriceOracle.setDirectPrice(address(TokenA), 1 * 1e30);
        simplePriceOracle.setDirectPrice(address(TokenB), 5 * 1e18);
        uint success = iComptroller._setCollateralFactor(CToken(address(cDelegatorB)), 0.5 * 1e18);
        require(success == 0, "set collateral factor fail");
        vm.stopPrank();

        // mint 1000 cUNI
        vm.startPrank(user1);
        uint mintAmount = 1000 * 10 ** TokenB.decimals();
        TokenB.approve(address(cDelegatorB), mintAmount);
        success = cDelegatorB.mint(mintAmount);
        require(success == 0, "mint fail");
        assertEq(cDelegatorB.balanceOf(user1), mintAmount);

        // user1 enable cUNI in market
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cDelegatorB);
        uint[] memory successes = iComptroller.enterMarkets(cTokens);
        require(successes[0] == 0, "enter market fail");

        // user1 borrow 2500 USDC
        uint borrowAmount = 2500 * 10 ** TokenA.decimals();
        success = cDelegatorA.borrow(borrowAmount);
        require(success == 0, "borrow fail");
        assertEq(TokenA.balanceOf(user1), tokenAInitBalance + borrowAmount);
        vm.stopPrank();

        // UNI price drop to 4
        vm.startPrank(admin);
        simplePriceOracle.setDirectPrice(address(TokenB), 4 * 1e18);
        vm.stopPrank(); 

        // user2 deploy liquidator contract and liquidate user collaterals
        vm.startPrank(user2);
        uint closeFactorMantissa = iComptroller.closeFactorMantissa();
        uint liquidateAmount = borrowAmount * closeFactorMantissa / 1e18;
        Liquidator liquidator = new Liquidator();
        liquidator.execute(liquidateAmount, address(cDelegatorA), address(cDelegatorB), user1);
        vm.stopPrank();

        assertGt(TokenA.balanceOf(address(liquidator)), 63 * 10 ** TokenA.decimals());
        console.log(TokenA.balanceOf(address(liquidator))); // 63638693
    }


}