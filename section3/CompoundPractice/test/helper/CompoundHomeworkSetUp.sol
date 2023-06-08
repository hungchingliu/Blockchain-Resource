pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { Unitroller } from "compound-protocol/contracts/Unitroller.sol";
import { Comptroller } from "compound-protocol/contracts/Comptroller.sol";
import { ComptrollerInterface } from "compound-protocol/contracts/ComptrollerInterface.sol";
import { PriceOracle } from "compound-protocol/contracts/PriceOracle.sol";
import { SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import { InterestRateModel } from "compound-protocol/contracts/InterestRateModel.sol";
import { WhitePaperInterestRateModel } from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import { CErc20Delegate } from "compound-protocol/contracts/CErc20Delegate.sol";
import { CErc20Delegator } from "compound-protocol/contracts/CErc20Delegator.sol";
import { CToken } from "compound-protocol/contracts/CToken.sol";
import { Script } from "forge-std/Script.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

contract CompoundHomeworkSetUp is Test {
  address payable admin = payable(makeAddr("admin"));
  Unitroller unitroller;
  Comptroller comptroller;
  Comptroller iComptroller;
  SimplePriceOracle simplePriceOracle;
  PriceOracle priceOracle;
  ERC20 TokenA;
  ERC20 TokenB;
  CErc20Delegate cDelegateeA;
  CErc20Delegator cDelegatorA;
  CErc20Delegate cDelegateeB;
  CErc20Delegator cDelegatorB;

  function setUp() public virtual {
    vm.startPrank(admin);
    // 1. deploy Comptroller
    unitroller = new Unitroller();
    comptroller = new Comptroller();
    simplePriceOracle = new SimplePriceOracle();
    priceOracle = simplePriceOracle;
    uint closeFactor = 0;
    uint liquidationIncentive = 0;
    // Todo: declare comp
    // Todo: declare compRate
    
    unitroller._setPendingImplementation(address(comptroller));
    comptroller._become(unitroller);

    // execute delegate call
    iComptroller = Comptroller(address(unitroller));
    iComptroller._setLiquidationIncentive(liquidationIncentive);
    iComptroller._setCloseFactor(closeFactor);
    iComptroller._setPriceOracle(priceOracle);
    // Todo: set comp
    // Todo: set comp rate

    // 2. deploy underlying Erc20 token ABC
    TokenA = new ERC20("AAA", "AAA");
    TokenB = new ERC20("BBB", "BBB");

    // avoid stack too deep
    { 
      // 3. deploy CToken AAA
      uint baseRatePerYearA = 0;
      uint mutliplierPerYearA = 0;
      InterestRateModel interestRateModelA = new WhitePaperInterestRateModel(baseRatePerYearA, mutliplierPerYearA);
      uint exchangeRateMantissaA = 1 * 1e18;
      string memory nameA = "CToken AAA";
      string memory symbolA = "cAAA";
      uint8 decimalsA = 18;
      cDelegateeA = new CErc20Delegate();
      cDelegatorA = new CErc20Delegator(
        address(TokenA),
        iComptroller,
        interestRateModelA,
        exchangeRateMantissaA,
        nameA,
        symbolA,
        decimalsA,
        admin,
        address(cDelegateeA),
        "0x0" 
      );
    }

    {
      // 4. deploy CToken BBB
      uint baseRatePerYearB = 0;
      uint mutliplierPerYearB = 0;
      InterestRateModel interestRateModelB = new WhitePaperInterestRateModel(baseRatePerYearB, mutliplierPerYearB);
      uint exchangeRateMantissaB = 1 * 1e18;
      string memory nameB = "CToken BBB";
      string memory symbolB = "cBBB";
      uint8 decimalsB = 18;
      cDelegateeB = new CErc20Delegate();
      cDelegatorB = new CErc20Delegator(
        address(TokenB),
        iComptroller,
        interestRateModelB,
        exchangeRateMantissaB,
        nameB,
        symbolB,
        decimalsB,
        admin,
        address(cDelegateeB),
        "0x0" 
      );
    }

    // 5. add CTokenA CTokenB to market
    iComptroller._supportMarket(CToken(address(cDelegatorA)));
    iComptroller._supportMarket(CToken(address(cDelegatorB)));

    // 6. provide liquidity for TokenA, TokenB
    uint mintAmountA = 1000 * 10 ** TokenA.decimals(); 
    uint mintAmountB = 1000 * 10 ** TokenA.decimals(); 
    deal(address(TokenA), admin, mintAmountA);
    TokenA.approve(address(cDelegatorA), mintAmountA);
    cDelegatorA.mint(mintAmountA);
    deal(address(TokenB), admin, mintAmountB); 
    TokenB.approve(address(cDelegatorB), mintAmountB);
    cDelegatorB.mint(mintAmountB);
    vm.stopPrank();
  }
}
