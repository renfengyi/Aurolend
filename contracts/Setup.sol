pragma solidity ^0.8.0;

//cToken
import "./CToken/CErc20Delegator.sol";
import "./CToken/CErc20Delegate.sol";
import "./Governance/Comp.sol";
//comptroller
import "./Comptroller/Unitroller.sol";
import "./Comptroller/Comptroller.sol";
//interestModel
import "./InterestModel/JumpRateModelV2.sol";
//priceOracle
import "./Oracle/SimplePriceOracle.sol";
import "./Governance/Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Setup {
    using SafeERC20 for IERC20;
    address public TT1 = 0xe09D4de9f1dCC8A4d5fB19c30Fb53830F8e2a047;

    Comp public comp;
    CErc20Delegator public cTT1;
    CErc20Delegate	public cTT1Delegate;
    Unitroller		public unitroller;
    Comptroller	public comptroller;
    Comptroller	public unitrollerProxy;
    JumpRateModelV2	public interestRateModel;
    SimplePriceOracle	public priceOracle;
    Timelock public timelock;

    constructor() {
        timelock = new Timelock(msg.sender, uint(1 seconds));
        // governance token for borrow and incentives
        comp = new Comp(msg.sender);
        // price oracle set mannually
        priceOracle = new SimplePriceOracle();
        // interest rate model
        interestRateModel = new JumpRateModelV2(
                                5  * 10**18 / 100, // baseRatePerYear
                                12 * 10**18 / 100, // multiplierPerYear
                                24 * 10**18 / 100, // jumpMultiplierPerYear
                                80 * 10**18 / 100, // kink_
                                address(timelock)  // owner 
                                                );
        /* configure comptroller:
            1. unitroller as proxy with data storage; 
            2. comptroller as implementation;
        */
        unitroller = new Unitroller();
        comptroller = new Comptroller();
        unitrollerProxy = Comptroller(address(unitroller));
        unitroller._setPendingImplementation(address(comptroller)); // call from address(this)
        comptroller._become(unitroller);

        unitrollerProxy._setPriceOracle(priceOracle);
        // maximum fraction of origin loan that can be liquidated
        unitrollerProxy._setCloseFactor(500000000000000000); // 50%
        // collateral received as a multiplier of amount liquidator paid
        unitrollerProxy._setLiquidationIncentive(1080000000000000000); // 108%

        /* configure CToken:
            1. CErc20Delegator as proxy;
            2. CErc20Delegate as implementation;
        */
        cTT1Delegate = new CErc20Delegate();

        bytes memory data = new bytes(0x00);
        cTT1 = new CErc20Delegator(
                    TT1, // underlying token
                    ComptrollerInterface(address(unitroller)), 
                    InterestRateModel(address(interestRateModel)),
                    // 2 * 10 ** 8 cTT1 = 1 TT1
                    2 * 10 ** 8 * 10 ** 18, 
                    "Compound TT1", // name
                    "cTT1", // symbol
                    8, // decimals
                    address(uint160(address(this))), // admin
                    address(cTT1Delegate), // implementation
                    data
                   );    

        cTT1._setReserveFactor(25 * 10 ** 18 / 100); // 25% interest charged for reserve
        
        // set price of TT1
        priceOracle.setUnderlyingPrice(CToken(address(cTT1)), 1e18);
        // set markets supported by comptroller
        unitrollerProxy._supportMarket(CToken(address(cTT1)));
        // multiplier of collateral for borrowing cap 
        unitrollerProxy._setCollateralFactor(CToken(address(cTT1)), 
                                             60 * 10 ** 18 / 100);  // valid collateral rate is 60%

        CToken[] memory ct = new CToken[](1);
        ct[0] = CToken(address(cTT1));

        uint[] memory mbc = new uint[](1);
        mbc[0] = 0;

        uint[] memory bs = new uint[](1);
        bs[0] = 67 * 10 ** 18 / 1000;

        uint[] memory ss = new uint[](1);
        ss[0] = 67 * 10 ** 18 / 1000;

        unitrollerProxy._setMarketBorrowCaps(ct, mbc);
        unitrollerProxy._setCompSpeeds(ct, 
                                       bs, // supplySpeed: Comp per block
                                       ss  // borrowSpeed: Comp per block
                                      );
    }
}
