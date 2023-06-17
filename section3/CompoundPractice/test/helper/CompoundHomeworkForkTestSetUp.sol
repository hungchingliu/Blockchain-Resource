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
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

contract CompoundHomeworkForkTestSetUp is Test {
  // fork params
  address payable admin = payable(makeAddr("admin"));

  // deploy params 
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
    // fork ethereum mainnet
    string memory rpc = vm.envString("MAINNET_RPC_URL");
    uint256 forkId = vm.createFork(rpc);
    vm.selectFork(forkId);
    vm.rollFork(17_465_000);

    vm.startPrank(admin);
    // deploy Comptroller
    unitroller = new Unitroller();
    comptroller = new Comptroller();
    simplePriceOracle = new SimplePriceOracle();
    priceOracle = simplePriceOracle;
    uint closeFactor = 0.5e18;
    uint liquidationIncentive = 1.08 * 1e18;
    
    unitroller._setPendingImplementation(address(comptroller));
    comptroller._become(unitroller);

    // execute delegate call
    iComptroller = Comptroller(address(unitroller));
    iComptroller._setLiquidationIncentive(liquidationIncentive);
    iComptroller._setCloseFactor(closeFactor);
    iComptroller._setPriceOracle(priceOracle);

    // let tokenA = USDC, tokenB = UNI
    TokenA = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    TokenB = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

    // avoid stack too deep
    { 
      // deploy cUSDC
      uint baseRatePerYearA = 0;
      uint mutliplierPerYearA = 0;
      InterestRateModel interestRateModelA = new WhitePaperInterestRateModel(baseRatePerYearA, mutliplierPerYearA);
      uint exchangeRateMantissaA = 1 * 1e6; // 1e(18 - cToken decimals + underlying token decimals)
      string memory nameA = "CToken USDC";
      string memory symbolA = "cUSDC";
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
      // 4. deploy cUNI
      uint baseRatePerYearB = 0;
      uint mutliplierPerYearB = 0;
      InterestRateModel interestRateModelB = new WhitePaperInterestRateModel(baseRatePerYearB, mutliplierPerYearB);
      uint exchangeRateMantissaB = 1 * 1e18;
      string memory nameB = "CToken UNI";
      string memory symbolB = "cUNI";
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

    // add cUSDC cUNI to market
    iComptroller._supportMarket(CToken(address(cDelegatorA)));
    iComptroller._supportMarket(CToken(address(cDelegatorB)));

    // provide liquidity for USDC, UNI
    uint mintAmountA = 2500 * 10 ** TokenA.decimals(); 
    uint mintAmountB = 2500 * 10 ** TokenA.decimals(); 
    deal(address(TokenA), admin, mintAmountA);
    TokenA.approve(address(cDelegatorA), mintAmountA);
    cDelegatorA.mint(mintAmountA);
    deal(address(TokenB), admin, mintAmountB); 
    TokenB.approve(address(cDelegatorB), mintAmountB);
    cDelegatorB.mint(mintAmountB);
    vm.stopPrank();
  }
}
