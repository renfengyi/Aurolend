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

// underlying asset
import "./tokenForTest/TestERC20Asset.sol";

contract Setup {
    // address public TT1 = 0xe09D4de9f1dCC8A4d5fB19c30Fb53830F8e2a047;
    TestERC20Asset public TT1 = new TestERC20Asset("TT1", "T1");
    Comp public comp;
    CErc20Delegator public cTT1;
    CErc20Delegate public cTT1Delegate;
    Unitroller public unitrollerProxy;
    Comptroller public comptrollerImpl;
    Comptroller public unitrollerProxyToImpl;
    JumpRateModelV2 public interestRateModel;
    SimplePriceOracle public priceOracle;
    Timelock public timelock;

    constructor() {
        timelock = new Timelock(msg.sender, uint256(1 seconds));
        // governance token for borrow and incentives
        comp = new Comp(msg.sender);
        // price oracle set mannually
        priceOracle = new SimplePriceOracle();
        // interest rate model
        interestRateModel = new JumpRateModelV2(
            (5 * 10**18) / 100, // baseRatePerYear
            (12 * 10**18) / 100, // multiplierPerYear
            (24 * 10**18) / 100, // jumpMultiplierPerYear
            (80 * 10**18) / 100, // kink_
            address(timelock) // owner
        );
        /* configure comptroller:
            1. unitrollerProxy as proxy with data storage;
            2. comptrollerImpl as implementation;
        */
        unitrollerProxy = new Unitroller();
        comptrollerImpl = new Comptroller();
        unitrollerProxyToImpl = Comptroller(address(unitrollerProxy));
        unitrollerProxy._setPendingImplementation(address(comptrollerImpl));
        // call from address(this)
        comptrollerImpl._become(unitrollerProxy);

        unitrollerProxyToImpl._setPriceOracle(priceOracle);
        // maximum fraction of origin loan that can be liquidated
        unitrollerProxyToImpl._setCloseFactor(500000000000000000);
        // 50%
        // collateral received as a multiplier of amount liquidator paid
        unitrollerProxyToImpl._setLiquidationIncentive(1080000000000000000);
        // 108%

        /* configure CToken:
            1. CErc20Delegator as proxy;
            2. CErc20Delegate as implementation;
        */
        cTT1Delegate = new CErc20Delegate();

        bytes memory data = new bytes(0x00);
        cTT1 = new CErc20Delegator(
            address(TT1), // underlying token
            ComptrollerInterface(address(unitrollerProxy)),
            InterestRateModel(address(interestRateModel)),
            // 2 * 10 ** 8 cTT1 = 1 TT1
            2 * 10**8 * 10**18,
            "Compound TT1", // name
            "cTT1", // symbol
            8, // decimals
            address(uint160(address(this))), // admin
            address(cTT1Delegate), // implementation
            data
        );

        cTT1._setReserveFactor((25 * 10**18) / 100);
        // 25% interest charged for reserve

        // set price of TT1
        priceOracle.setUnderlyingPrice(CToken(address(cTT1)), 1e18);
        // set markets supported by comptroller
        unitrollerProxyToImpl._supportMarket(CToken(address(cTT1)));
        // multiplier of collateral for borrowing cap
        unitrollerProxyToImpl._setCollateralFactor(
            CToken(address(cTT1)),
            (60 * 10**18) / 100
        );
        // valid collateral rate is 60%

        CToken[] memory ct = new CToken[](1);
        ct[0] = CToken(address(cTT1));

        uint256[] memory mbc = new uint256[](1);
        mbc[0] = 0;

        uint256[] memory bs = new uint256[](1);
        bs[0] = (67 * 10**18) / 1000;

        uint256[] memory ss = new uint256[](1);
        ss[0] = (67 * 10**18) / 1000;

        unitrollerProxyToImpl._setMarketBorrowCaps(ct, mbc);
        unitrollerProxyToImpl._setCompSpeeds(
            ct,
            bs, // supplySpeed: Comp per block
            ss // borrowSpeed: Comp per block
        );
    }
}
