const {expect} = require("chai");
const {ethers} = require("hardhat");
const {getInstance} = require("./utils");

describe("TT1", async () => {
    let sender, TT1, tt1Ins;
    before(async () => {
        [sender,] = await ethers.getSigners();
        TT1 = "0x9fB47402890C87917DF7680DEE29d9Bf6ba8fc6E"
        tt1Ins = await getInstance("TestERC20Asset", TT1);
    })
    describe("base function test",async ()=>{
        it('should balanceOf not zero', async () => {
           expect(await tt1Ins.balanceOf(sender.address)).to.above(0);
        });

        it('should transfer', function () {

        });
    })


    describe("redeem", () => {

    })
});
