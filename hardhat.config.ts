import { HardhatUserConfig } from "hardhat/types";
import "@shardlabs/starknet-hardhat-plugin";
import "@nomiclabs/hardhat-ethers";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  solidity: '0.6.12',

  networks: {
    devnet: {
      url: "http://127.0.0.1:5050"
    },

    hardhat: {}
  },
};

export default config;