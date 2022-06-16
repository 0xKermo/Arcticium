// Add extension to starknet
require("@shardlabs/starknet-hardhat-plugin");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  starknet: {
    network: "develop"
  },
  // We define our test network, which we will run locally with.
  networks: {
    develop: {
      url: "http://127.0.0.1:500"
    }
  },
  cairo: {
    // Version of the plugin which is execute on the docker
    version: "0.6.2"
  },
  paths: {
    // Where are our contracts: ./contracts
    starknetSources:"./contracts",
    // Where are our artifacts (build contract): ./stark-artifacts, not use repository "artifacts" which is reserved by hardhat to solidity
    starknetArtifacts: "./starknet-artifacts",
  },
  mocha: {
    // set up the network to run our test
    starknetNetwork: "develop"
  }
};