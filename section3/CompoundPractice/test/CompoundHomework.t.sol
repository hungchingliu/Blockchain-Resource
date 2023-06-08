// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;
import "test/helper/CompoundHomeworkSetUp.sol";
import "forge-std/console.sol";
contract CompoundHomework is CompoundHomeworkSetUp {
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    uint constant tokenAInitBalance = 100 * 1e18;
    uint constant tokenBInitBalance = 100 * 1e18;

    function setUp() public override {
        super.setUp();
        // give user1, user2 initial balance
        deal(address(TokenA), user1, tokenAInitBalance);
        deal(address(TokenB), user1, tokenBInitBalance);
        deal(address(TokenA), user2, tokenAInitBalance); 
        deal(address(TokenB), user2, tokenBInitBalance);
    }

    function test_mint_redeem() public {
        uint mintAmount = 100 * 10 ** TokenA.decimals();
        
        vm.startPrank(user1);
        
        // 1. approve compound to use TokenA
        TokenA.approve(address(cDelegatorA), mintAmount);
        
        // 2. mint CToken
        uint success = cDelegatorA.mint(mintAmount);
        require(success == 0, "mint fail");
        assertEq(cDelegatorA.balanceOf(user1), mintAmount); // exchange rate = 1:1, so CToken = mintAmount
        
        // 3. redeem TokenA
        success = cDelegatorA.redeemUnderlying(mintAmount);
        require(success == 0, "redeem fail");
        assertEq(mintAmount, TokenA.balanceOf(user1));
        
        vm.stopPrank();
    }

    function test_borrow_repay() public {
        // 1. set price of TokenA, TokenB and set TokenB collateral factor
        vm.startPrank(admin);
        simplePriceOracle.setDirectPrice(address(TokenA), 1 * 1e18);
        simplePriceOracle.setDirectPrice(address(TokenB), 100 * 1e18);
        uint success = iComptroller._setCollateralFactor(CToken(address(cDelegatorB)), 0.5 * 1e18);
        require(success == 0, "set collateral factor fail");
        vm.stopPrank();

        // 2. mint 1 CTokenB with 1 TokenB
        vm.startPrank(user1);
        uint mintAmount = 1 * 10 ** TokenB.decimals();
        TokenB.approve(address(cDelegatorB), mintAmount);
        success = cDelegatorB.mint(mintAmount);
        require(success == 0, "mint fail");
        assertEq(cDelegatorB.balanceOf(user1), mintAmount);
        
        // 3. user1 enable CTokenB in market
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cDelegatorB);
        uint[] memory successes = iComptroller.enterMarkets(cTokens);
        require(successes[0] == 0, "enter market fail");
        
        // 4. user1 borrow 50 TokenA
        uint borrowAmount = 50 * 10 ** TokenA.decimals();
        success = cDelegatorA.borrow(borrowAmount);
        require(success == 0, "borrow fail");
        assertEq(TokenA.balanceOf(user1), tokenAInitBalance + borrowAmount);

        // 5. user1 repay 50 TokenA
        TokenA.approve(address(cDelegatorA), borrowAmount);
        success = cDelegatorA.repayBorrow(borrowAmount);
        require(success == 0, "repay fail");

        // 6. user1 disable CTokenB in market, no debt left 
        success = iComptroller.exitMarket(cTokens[0]);
        require(success == 0, "exit market fail");
    }

    function test_liquidate_by_adjust_collateral_factor() public {
        // 1. set price of TokenA, TokenB, TokenB collateral factor, close factor and liquidation incentive
        vm.startPrank(admin);
        simplePriceOracle.setDirectPrice(address(TokenA), 1 * 1e18);
        simplePriceOracle.setDirectPrice(address(TokenB), 100 * 1e18);
        uint success = iComptroller._setCollateralFactor(CToken(address(cDelegatorB)), 0.5 * 1e18);
        require(success == 0, "set collateral factor fail");
        success = iComptroller._setCloseFactor(0.5 * 1e18);
        require(success == 0, "set close factor fail");
        success = iComptroller._setLiquidationIncentive(1 * 1e18);
        require(success == 0, "set liquidation incenctive fail");
        vm.stopPrank();

        // 2. mint 1 CTokenB with 1 TokenB
        vm.startPrank(user1);
        uint mintAmount = 1 * 10 ** TokenB.decimals();
        TokenB.approve(address(cDelegatorB), mintAmount);
        success = cDelegatorB.mint(mintAmount);
        require(success == 0, "mint fail");
        assertEq(cDelegatorB.balanceOf(user1), mintAmount);
        
        // 3. user1 enable CTokenB in market
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cDelegatorB);
        uint[] memory successes = iComptroller.enterMarkets(cTokens);
        require(successes[0] == 0, "enter market fail");
        
        // 4. user1 borrow 50 TokenA
        uint borrowAmount = 50 * 10 ** TokenA.decimals();
        success = cDelegatorA.borrow(borrowAmount);
        require(success == 0, "borrow fail");
        assertEq(TokenA.balanceOf(user1), tokenAInitBalance + borrowAmount);
        vm.stopPrank();

        // 5. compound governance decide to adjust TokenB collater factor to 0.1
        vm.startPrank(admin);
        iComptroller._setCollateralFactor(CToken(address(cDelegatorB)), 0.1 * 1e18);
        vm.stopPrank(); 

        // 6. user2 liquidate user1 collateral asset
        vm.startPrank(user2);
        uint closeFactorMantissa = iComptroller.closeFactorMantissa();
        uint liquidateAmount = borrowAmount * closeFactorMantissa / 1e18;
        TokenA.approve(address(cDelegatorA), liquidateAmount);
        success = cDelegatorA.liquidateBorrow(user1, liquidateAmount, cDelegatorB);
        require(success == 0, "liquidate fail");
        // protocolSeizeShareMantissa = 2.8e16
        // seizeAmount = borrowAmount * closeFactor * liquidationIncentive * (1 - protocolSeizeShare) * tokenAPrice / tokenBPrice
        // 0.243 = 50 * 0.5 * 1 * 0.972 * 1 / 100
        assertEq(cDelegatorB.balanceOf(user2), 0.243 * 1e18);
        vm.stopPrank();
    }

    function test_liquidate_by_adjust_TokenB_price() public {
        // 1. set price of TokenA, TokenB, TokenB collateral factor, close factor and liquidation incentive
        vm.startPrank(admin);
        simplePriceOracle.setDirectPrice(address(TokenA), 1 * 1e18);
        simplePriceOracle.setDirectPrice(address(TokenB), 100 * 1e18);
        uint success = iComptroller._setCollateralFactor(CToken(address(cDelegatorB)), 0.5 * 1e18);
        require(success == 0, "set collateral factor fail");
        success = iComptroller._setCloseFactor(0.5 * 1e18);
        require(success == 0, "set close factor fail");
        success = iComptroller._setLiquidationIncentive(1 * 1e18);
        require(success == 0, "set liquidation incenctive fail");
        vm.stopPrank();

        // 2. mint 1 CTokenB with 1 TokenB
        vm.startPrank(user1);
        uint mintAmount = 1 * 10 ** TokenB.decimals();
        TokenB.approve(address(cDelegatorB), mintAmount);
        success = cDelegatorB.mint(mintAmount);
        require(success == 0, "mint fail");
        assertEq(cDelegatorB.balanceOf(user1), mintAmount);
        
        // 3. user1 enable CTokenB in market
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cDelegatorB);
        uint[] memory successes = iComptroller.enterMarkets(cTokens);
        require(successes[0] == 0, "enter market fail");
        
        // 4. user1 borrow 50 TokenA
        uint borrowAmount = 50 * 10 ** TokenA.decimals();
        success = cDelegatorA.borrow(borrowAmount);
        require(success == 0, "borrow fail");
        assertEq(TokenA.balanceOf(user1), tokenAInitBalance + borrowAmount);
        vm.stopPrank();

        // 5. TokenB price drop to 50
        vm.startPrank(admin);
        simplePriceOracle.setDirectPrice(address(TokenB), 50 * 1e18);
        vm.stopPrank(); 

        // 6. user2 liquidate user1 collateral asset
        vm.startPrank(user2);
        uint closeFactorMantissa = iComptroller.closeFactorMantissa();
        uint liquidateAmount = borrowAmount * closeFactorMantissa / 1e18;
        TokenA.approve(address(cDelegatorA), liquidateAmount);
        success = cDelegatorA.liquidateBorrow(user1, liquidateAmount, cDelegatorB);
        require(success == 0, "liquidate fail");
        // protocolSeizeShareMantissa = 2.8e16
        // seizeAmount = borrowAmount * closeFactor * liquidationIncentive * (1 - protocolSeizeShare) * tokenAPrice / tokenBPrice
        // 0.486 = 50 * 0.5 * 1 * 0.972 * 1 / 50
        assertEq(cDelegatorB.balanceOf(user2), 0.486 * 1e18);
        vm.stopPrank();
    }
}