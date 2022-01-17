const {expect} = require("chai");
const {ethers} = require("hardhat");
const {getInstance} = require("./utils");
const TT1 = "0x9fB47402890C87917DF7680DEE29d9Bf6ba8fc6E"

describe("TT1", async () => {
    const tt1Ins = await getInstance("TestERC20Asset", TT1);
    const [sender,] = await ethers.getSigners();
    console.log(await tt1Ins.balanceOf(sender.address));
    // describe("supply", () => {
    //     it('should approve the CToken', function () {
    //
    //     });
    //     //
    // })
    describe("redeem", () => {

    })
});
