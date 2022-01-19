const {ethers} = require("hardhat");

async function getInstance(name, address) {
    const factory = await ethers.getContractFactory(name);
    return factory.attach(address);
}

async function getLogs(tx, eventName, name) {
    let receipt = await tx.wait()
    // todo check
    let evt = receipt.events?.filter((x) => {
        return x.event == eventName
    })
    // console.log(evt)
    return evt[0].args[name]
}

async function deployContract(name, args) {
    const factory = await ethers.getContractFactory(name);
    return await factory.deploy(...args)
}

module.exports = {
    deployContract,
    getInstance,
    getLogs
}