const {expect} = require("chai");
const {ethers, getNamedAccounts} = require("hardhat");
const {getLogs, deployContract} = require("./utils");

describe("stableCoinTest", async () => {
    let LQDF, sender;
    before(async () => {
        LQDF = await deployContract("LQDF", []);
        [sender] = await ethers.getSigners();
    })
    it('mint', async () => {
        let mintAmount = 10000;
        await LQDF.approve(sender.address, mintAmount);
        let tx = await LQDF.mint(sender.address, mintAmount);
        let receipt = await tx.wait()
        let evt = receipt.events?.filter((x) => {
            return x.event == "Transfer"
        })
        expect(evt[0].args["value"]).to.equal(mintAmount)
    });

    it('burn', async () => {
        let burnAmount = 10000;
        expect(await getLogs(await LQDF.burn(burnAmount), "Transfer", "value")).to.eq(burnAmount)
    })
});
