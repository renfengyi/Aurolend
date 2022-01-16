/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require('dotenv').config()

require("@nomiclabs/hardhat-waffle");

module.exports = {
    solidity: {
        version: "0.8.0",
        settings: {
            optimizer: {
                enabled: true,
                runs: 1000,
            },
        },
    },
    networks: {
        rinkeby: {
            url: `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`,
            accounts: [process.env.KEY1, process.env.KEY2]
        },
        aurora_test: {
            url: `https://testnet.aurora.dev/`,
            chainId: 1313161555,
            accounts: [process.env.KEY0,process.env.KEY1, process.env.KEY2],
        },
        aurora:{
            url: `https://mainnet.aurora.dev`,
            chainId: 1313161554,
            accounts: [process.env.KEY0,process.env.KEY1, process.env.KEY2],
        }
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    mocha: {
        timeout: 20000  // 运行单元测试的最大等待时间
    }
};
