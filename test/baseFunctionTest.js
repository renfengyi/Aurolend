const {expect} = require("chai");
const {ethers} = require("hardhat");
const {getLogs} = require("./utils");
const {deployCompound} = require("./separateDeploy")
const {BigNumber} = require("ethers");
describe("CToken", async () => {
    let contracts, ctt1, interestModel, tt1, sender, priceOracle, ctt2, tt2, liquidator;
    before(async () => {
        // 部署compound
        contracts = await deployCompound();
        ctt1 = contracts.cTT1;
        ctt2 = contracts.cTT2;
        interestModel = contracts.interestModel;
        tt1 = contracts.TT1;
        tt2 = contracts.TT2;
        priceOracle = contracts.priceOracle;
        [sender, liquidator] = await ethers.getSigners();

        //    transfer to liquidator
        //    event Transfer(address indexed from, address indexed to, uint256 value);
        let mintAmount = BigNumber.from(10).pow(10);
        let tx = await tt2.mint(liquidator.address, mintAmount);
        expect(await getLogs(tx, "Transfer", "value")).eq(mintAmount);
    })
    // it('get supply & borrow interest', async () => {
    //     let cash, borrows, reserves
    //     cash = await ctt1.balanceOf(contracts.cTT1.address)
    //     const tx = await ctt1.totalBorrowsCurrent()
    //     let receipt = await tx.wait()
    //     borrows = receipt.events[0].args["totalBorrows"]
    //
    //     reserves = await ctt1.totalReserves()
    //     const borrowRate = await interestModel.getBorrowRate(cash, borrows, reserves)
    //     borrowRate
    // })
    it('mint', async () => {
        let mintAmout = 10000
        // approve
        await tt1.approve(ctt1.address, mintAmout);
        let tx = await ctt1.mint(mintAmout);
        expect(await getLogs(tx, "Mint", "mintAmount")).to.equal(mintAmout)

        // console.log("mintTokens", (await getLogs(tx, "Mint", "mintTokens")).toString())
    });

    it('redeem', async () => {
        //    查询存的总额
        // let tx = await cTT1.balanceOfUnderlying(sender.address)
        // let receipt = await tx.wait()
        // console.log(receipt)
        //    取出
        let redeemAmount = 100
        expect(await getLogs(await ctt1.redeemUnderlying(redeemAmount), "Redeem", "redeemAmount")).to.eq(redeemAmount)
    })
    it("borrow", async () => {
        let borrowAmount = 100
        expect(await getLogs(await ctt1.borrow(borrowAmount), "Borrow", "borrowAmount")).eq(borrowAmount)
        // emit Borrow(borrower, borrowAmount, vars.accountBorrowsNew, vars.totalBorrowsNew);
    })
    it("repay", async () => {

        let repayAmount = 100
        await tt1.approve(ctt1.address, repayAmount);
        expect(await getLogs(await ctt1.repayBorrow(repayAmount), "RepayBorrow", "repayAmount")).eq(repayAmount)
    })

    it("liquidation", async () => {
        let mintAmout = 10000
        let borrowAmout = 1000
        //    tt1 mint
        await tt1.approve(ctt1.address, mintAmout);
        let tx = await ctt1.mint(mintAmout);
        expect(await getLogs(tx, "Mint", "mintAmount")).to.equal(mintAmout)
        // tt2 mint
        await tt2.connect(liquidator).approve(ctt2.address, mintAmout, {from: liquidator.address});
        expect(await getLogs(await ctt2.connect(liquidator).mint(mintAmout), "Mint", "mintAmount")).to.equal(mintAmout)

        //    tt2 borrow
        expect(await getLogs(await ctt2.borrow(borrowAmout), "Borrow", "borrowAmount")).eq(borrowAmout)
        //    reduce price of tt1
        const factor18 = BigNumber.from(10).pow(18);
        let newPrice = BigNumber.from(1).mul(factor18);
        await priceOracle.setUnderlyingPrice(ctt1.address, newPrice);
        //    liquidate
        // function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) external override returns (uint) {
        // LiquidateBorrow(address liquidator, address borrower, uint repayAmount, address cTokenCollateral, uint seizeTokens);
        let liquidateAmount = 1
        await tt2.connect(liquidator).approve(ctt2.address, liquidateAmount);
        let txl = await ctt2.connect(liquidator).liquidateBorrow(sender.address, liquidateAmount, ctt1.address);
        expect(await getLogs(txl, "LiquidateBorrow", "repayAmount")).eq(liquidateAmount);

    })

});
