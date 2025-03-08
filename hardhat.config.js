require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");

module.exports = {
  solidity: "0.8.28",
  networks: {
    hardhat: {},
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};