const {ethers} = require("hardhat");
const {BigNumber} = require("ethers");
const {addPool, initPool} = require("./compoundAsset");
const {deployContract} = require("./utils");

async function deployCompound() {
    // 账号
    const [sender,] = await ethers.getSigners();

    // 部署timelock
    const timelockFactory = await ethers.getContractFactory("Timelock");
    const timelockInstance = await timelockFactory.deploy(sender.address, BigNumber.from("1"));
    // comp
    const comp = await deployContract("Comp", [sender.address])
    // oracle
    const priceOracle = await deployContract("SimplePriceOracle", []);

    // factor
    const facotr = BigNumber.from(1).mul(10).pow(18).div(100);
    const factor16 = BigNumber.from(10).pow(16);
    const factor18 = BigNumber.from(10).pow(18);

    const interestModel = await deployContract("JumpRateModelV2", [
        ((BigNumber.from(5)).mul(facotr)),//baseRatePerYear
        (BigNumber.from(12).mul(facotr)),//multiplierPerYear
        (BigNumber.from(24).mul(facotr)),//jumpMultiplierPerYear
        (BigNumber.from(80).mul(facotr)),//kink_
        timelockInstance.address // owner
    ])


    const unitrollerProxy = await deployContract("Unitroller", []);
    const comptrollerImpl = await deployContract("Comptroller", []);
    // console.log("comptrollerImpl: ", comptrollerImpl.address);
    await unitrollerProxy._setPendingImplementation(comptrollerImpl.address);
    await comptrollerImpl._become(unitrollerProxy.address);

    const unitrollerProxyToImplFa = await ethers.getContractFactory("Comptroller");
    const unitrollerProxyToImpl = unitrollerProxyToImplFa.attach(unitrollerProxy.address);

    // 初始化comptroller参数
    await unitrollerProxyToImpl._setPriceOracle(priceOracle.address);
    // maximum fraction of origin loan that can be liquidated
    await unitrollerProxyToImpl._setCloseFactor(BigNumber.from(50).mul(facotr));

    // 50%
    // collateral received as a multiplier of amount liquidator paid
    await unitrollerProxyToImpl._setLiquidationIncentive(BigNumber.from(108).mul(facotr));
    // 108%


    // add pool 1
    // 底层资产
    const TT1 = await deployContract("TestERC20Asset", ["TT1", "T1"]);
    const data = "0x00";
    const cTT1 = await addPool(
        TT1.address,
        unitrollerProxy.address,
        interestModel.address,
        BigNumber.from(2).mul(factor16),
        "Compound cTT1",
        "cTT1",
        8,
        sender.address,
        data
    )
    //await cTT1._setReserveFactor(BigNumber.from(25).mul(facotr));
    // // set price of TT1
    // await priceOracle.setUnderlyingPrice(cTT1.address, BigNumber.from(1).mul(facotr).mul(100));
    // // set markets supported by comptroller
    // await unitrollerProxyToImpl._supportMarket(cTT1.address);
    // // multiplier of collateral for borrowing cap
    // await unitrollerProxyToImpl._setCollateralFactor(
    //     cTT1.address,
    //     BigNumber.from(60).mul(facotr)
    // );
    let reserveFactor = BigNumber.from(25).mul(facotr);
    let underlyingPrice = 100;
    let collateralFactor = BigNumber.from(60).mul(facotr);
    let contracts = {priceOracle: priceOracle, unitrollerProxyToImpl: unitrollerProxyToImpl,}
    let compSpeed = BigNumber.from(67).mul(facotr).div(10)
    await initPool(
        cTT1,
        contracts,
        reserveFactor,
        BigNumber.from(underlyingPrice).mul(factor18),
        collateralFactor,
        0,
        compSpeed,
        compSpeed
    )


    // add pool 2
    const TT2 = await deployContract("TestERC20Asset", ["TT2", "T2"]);
    const cTT2 = await addPool(TT2.address,
        unitrollerProxy.address,
        interestModel.address,
        BigNumber.from(2).mul(factor16),
        "Compound cTT2",
        "cTT2",
        8,
        sender.address,
        data
    )
    await initPool(
        cTT2,
        contracts,
        reserveFactor,
        BigNumber.from(underlyingPrice).mul(factor18),
        collateralFactor,
        0,
        compSpeed,
        compSpeed
    )

    return {
        TT1: TT1,
        TT2: TT2,
        comp: comp,
        cTT1: cTT1,
        cTT2: cTT2,
        unitrollerProxy: unitrollerProxy,
        priceOracle: priceOracle,
        interestModel: interestModel
    };


}


module.exports = {
    deployCompound,
}