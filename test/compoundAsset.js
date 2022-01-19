const {deployContract} = require("./utils");

async function addPool(underlyingAsset, comptroller, interestModel, exchangeRate, cTokenName, cTokenSymbol, decimals, admin, initData) {
    const cTT1Delegate = await deployContract("CErc20Delegate", []);
    return await deployContract("CErc20Delegator",
        [
            underlyingAsset,
            comptroller,
            interestModel,
            exchangeRate,
            cTokenName, // name
            cTokenSymbol, // symbol
            decimals, // decimals
            admin,
            cTT1Delegate.address,
            initData
        ]
    );
}


async function initPool(pool, contracts, reserveFactor, underlyingPrice, collateralFactor, borrowCap, compSupplySpeed, compBorrowSpeed) {
    await pool._setReserveFactor(reserveFactor);
    // 25% interest charged for reserve


    // set price of TT1
    await contracts.priceOracle.setUnderlyingPrice(pool.address, underlyingPrice);
    // set markets supported by comptroller
    await contracts.unitrollerProxyToImpl._supportMarket(pool.address);
    // multiplier of collateral for borrowing cap
    await contracts.unitrollerProxyToImpl._setCollateralFactor(
        pool.address,
        collateralFactor
    );
    // valid collateral rate is 60%

    const ct = [pool.address]
    const mbc = [borrowCap]
    const bs = [compSupplySpeed]
    const ss = [compBorrowSpeed]

    await contracts.unitrollerProxyToImpl._setMarketBorrowCaps(ct, mbc);
    await contracts.unitrollerProxyToImpl._setCompSpeeds(
        ct,
        ss, // supplySpeed: Comp per block
        bs// borrowSpeed: Comp per block
    );
}


module.exports = {
    addPool,
    initPool
}