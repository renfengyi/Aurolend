const {expect} = require("chai");
const {ethers} = require("hardhat");
const {deployContract} = require("./utils");
describe("TT1", async () => {
    let sender, ins;
    before(async () => {
        [sender, reciver] = await ethers.getSigners();
        ins = await deployContract("TestERC20Asset",["TestERC20Asset","TT1"])
    })
    describe("base function test", async () => {
        it('should balanceOf not zero', async () => {
            expect(await ins.balanceOf(sender.address)).to.above(0)
        });

        it('should transfer', async function () {
            // let ans = await tt1Ins.transfer(reciver.address, 1);
            // console.log("transfer ans", ans);
        });
    })


    describe("redeem", () => {

    })
});
