require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
const dotenv = require("dotenv");
const path = require("path");

dotenv.config();

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    sepolia: {
      url: process.env.REACT_APP_SEPOLIA_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
    polygonMumbai: {
      url: process.env.REACT_APP_MUMBAI_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.REACT_APP_ETHERSCAN_KEY,
      polygonMumbai: process.env.REACT_APP_POLYGONSCAN_KEY,
    },
  },
  paths: {
    sources: path.join(__dirname, "contracts"),
    artifacts: path.join(__dirname, "artifacts"),
    cache: path.join(__dirname, "cache"),
    tests: path.join(__dirname, "test"),
  },
};
