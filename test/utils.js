const {ethers} = require("hardhat");

async function getInstance(name, address) {
    const factory = await ethers.ContractFactory(name);
    return await factory.attach(address);
}


module.exports = {
    getInstance
}