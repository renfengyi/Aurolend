const {expect} = require("chai");
const {ethers} = require("hardhat");
const {getLogs} = require("./utils");
const {deployCompound} = require("./separateDeploy")
describe("CToken", async () => {
    let contracts, cTT1, interestModel, tt1, sender;
    before(async () => {
        // 部署compound
        contracts = await deployCompound();
        cTT1 = contracts.cTT1;
        interestModel = contracts.interestModel;
        tt1 = contracts.TT1;
        [sender] = await ethers.getSigners();

    })
    it('get supply & borrow interest', async () => {
        let cash, borrows, reserves
        cash = await cTT1.balanceOf(contracts.cTT1.address)
        const tx = await cTT1.totalBorrowsCurrent()
        let receipt = await tx.wait()
        borrows = receipt.events[0].args["totalBorrows"]

        reserves = await cTT1.totalReserves()
        const borrowRate = await interestModel.getBorrowRate(cash, borrows, reserves)
        borrowRate
    })
    it('mint', async () => {
        let mintAmout = 10000
        // approve
        await tt1.approve(cTT1.address, mintAmout);
        let tx = await cTT1.mint(mintAmout);
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
        expect(await getLogs(await cTT1.redeemUnderlying(redeemAmount), "Redeem", "redeemAmount")).to.eq(redeemAmount)
    })
    it("borrow", async () => {
        let borrowAmount = 100
        expect(await getLogs(await cTT1.borrow(borrowAmount), "Borrow", "borrowAmount")).eq(borrowAmount)
        // emit Borrow(borrower, borrowAmount, vars.accountBorrowsNew, vars.totalBorrowsNew);
    })
    it("repay", async () => {

        let repayAmount = 100
        await tt1.approve(cTT1.address, repayAmount);
        expect(await getLogs(await cTT1.repayBorrow(repayAmount), "RepayBorrow", "repayAmount")).eq(repayAmount)
    })

    it("liquidation", async () => {

    })

});
