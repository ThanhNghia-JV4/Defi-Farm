require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  networks: {
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${alchemyApiKey}`, //thay doi
      accounts: { mnemonic: mnemonic }, //thay doi
    },
  },
  paths: {
    artifacts: "./client/src/artifacts"
  },
  etherscan: {
    apiKey: `${etherScanKey}`, //thay doi 
  },

};
