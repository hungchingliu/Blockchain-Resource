pragma solidity 0.8.19;
import { Unitroller } from "compound-protocol/contracts/Unitroller.sol";
import { Comptroller } from "compound-protocol/contracts/Comptroller.sol";
import { ComptrollerInterface } from "compound-protocol/contracts/ComptrollerInterface.sol";
import { PriceOracle } from "compound-protocol/contracts/PriceOracle.sol";
import { SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import { InterestRateModel } from "compound-protocol/contracts/InterestRateModel.sol";
import { WhitePaperInterestRateModel } from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import { CErc20Delegate } from "compound-protocol/contracts/CErc20Delegate.sol";
import { CErc20Delegator } from "compound-protocol/contracts/CErc20Delegator.sol";
import { Script } from "forge-std/Script.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

contract CompoundDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. deploy Comptroller
        Unitroller unitroller = new Unitroller();
        Comptroller comptroller = new Comptroller();
        PriceOracle priceOracle = new SimplePriceOracle();
        uint closeFactor = 0;
        uint liquidationIncentive = 0;
        // Todo: declare comp
        // Todo: declare compRate
        
        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);

        // execute delegate call
        Comptroller iComptroller = Comptroller(address(unitroller));
        iComptroller._setLiquidationIncentive(liquidationIncentive);
        iComptroller._setCloseFactor(closeFactor);
        iComptroller._setPriceOracle(priceOracle);
        // Todo: set comp
        // Todo: set comp rate

        // 2. deploy underlying Erc20 token ABC
        ERC20 ABCToken = new ERC20("ABC", "ABC");
        
        // 3. deploy CToken
        uint baseRatePerYear = 0;
        uint mutliplierPerYear = 0;
        InterestRateModel interestRateModel = new WhitePaperInterestRateModel(baseRatePerYear, mutliplierPerYear);
        uint exchangeRateMantissa = 1 * 1e18;
        string memory name = "CToken ABC";
        string memory symbol = "cABC";
        uint8 decimals = 18;
        address payable admin = payable(msg.sender);
        CErc20Delegate cDelegatee = new CErc20Delegate();
        CErc20Delegator cDelegator = new CErc20Delegator(
           address(ABCToken),
           iComptroller,
           interestRateModel,
           exchangeRateMantissa,
           name,
           symbol,
           decimals,
           admin,
           address(cDelegatee),
           "0x0" 
        );
        
        vm.stopBroadcast();
    }
}