//we import expect to test values
const { expect } = require("chai");
// These two lines allow us to play with our testnet and access our deployed contract 
const { starknet } = require("hardhat");
const { number, uint256 } = require("starknet");

const { StarknetContract, StarknetContractFactory } = require("hardhat/types/runtime");
const {
  toUint256WithFelts,
  tryCatch,
  shouldFail,
  fromUint256WithFelts,
  strToFeltArr,
  feltArrToStr,
} = require('./utils/util')
// import library to transform string <>decimal
const { Account } = require("@shardlabs/starknet-hardhat-plugin/dist/src/account");
// const  { deployERC721 } =  require("./utils/deploy_util");

describe("exchange Test Cases", function () {

  this.timeout(300_000);
  let contract;
  let acc1;
  let acc2;
  let erc20;
  let owner;

  before(async function () {
    acc1 = await starknet.deployAccount("OpenZeppelin");
    acc2 = await starknet.deployAccount("OpenZeppelin");
    erc20 = await starknet.deployAccount("OpenZeppelin");
    console.log("Deployed acc1 address: ", acc1.starknetContract.address);
    console.log("Deployed acc2 address: ", acc2.starknetContract.address);
    console.log("Deployed erc20 address: ", erc20.starknetContract.address);

    const contractFactory = await starknet.getContractFactory("exchange");
    owner = BigInt(acc1.starknetContract.address)
    erc20 = BigInt(erc20.starknetContract.address)
    contract = await contractFactory.deploy({
      owner,
      erc20
    });

    console.log("Successfully deployed", contract.address);
  });
});
