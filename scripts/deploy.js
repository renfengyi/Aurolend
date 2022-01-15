const { ethers } = require("hardhat");

async function main() {
    const factory = await ethers.getContractFactory("Setup");
    const instance = await factory.deploy();
    console.log("setup address:", await instance.address);
    console.log("TestERC20Asset address:", await instance.TT1());
    console.log("Comp address:", await instance.comp());
    console.log("CErc20Delegator address:", await instance.cTT1())
    console.log("Unitroller address:", await instance.unitrollerProxy())
    console.log("priceOracle address:", await instance.priceOracle())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });