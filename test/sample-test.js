//we import expect to test values
const { expect } = require("chai");
// These two lines allow us to play with our testnet and access our deployed contract 
const { starknet } = require("hardhat");
const { number, uint256 } = require("starknet");

const { StarknetContract, StarknetContractFactory } = require("hardhat/types/runtime");
// const {
//   toUint256WithFelts,
//   tryCatch,
//   shouldFail,
//   fromUint256WithFelts,
//   strToFeltArr,
//   feltArrToStr,
// } = require('./utils/util')
// import library to transform string <>decimal
const { Account } = require("@shardlabs/starknet-hardhat-plugin/dist/src/account");
// const  { deployERC721 } =  require("./utils/deploy_util");

describe("ERC721 Test Cases", function () {

  this.timeout(300_000);
  let contract;
  let acc1;
  let acc2;
  let acc3;
  let owner;

  before(async function () {
    acc1 = await starknet.deployAccount("OpenZeppelin");
    acc2 = await starknet.deployAccount("OpenZeppelin");
    acc3 = await starknet.deployAccount("OpenZeppelin");
    console.log("Deployed acc1 address: ", acc1.starknetContract.address);
    console.log("Deployed acc2 address: ", acc2.starknetContract.address);
    console.log("Deployed acc3 address: ", acc3.starknetContract.address);

    const name = starknet.shortStringToBigInt("Arcswap");
    const symbol = starknet.shortStringToBigInt("ARC");
    const contractFactory = await starknet.getContractFactory("ERC721");
    owner = BigInt(acc1.starknetContract.address)
    contract = await contractFactory.deploy({
      name,
      symbol,
      owner
    });

    console.log("Successfully deployed", contract.address);

    // Call getter functions
    const n = (await contract.call("name")).name;
    const s = (await contract.call("symbol")).symbol;


    // Expect to match inputs
    expect(n).to.deep.equal(name);
    expect(s).to.deep.equal(symbol);

  });

  it("Should create a NFT and get this informations.", async function () {
    function toUint256WithFelts(num) {
      const n = uint256.bnToUint256(num);
      return {
        low: BigInt(n.low.toString()),
        high: BigInt(n.high.toString()),
      };
    }
    const toWallet = BigInt(acc2.starknetContract.address);
    const num0 = toUint256WithFelts("0");
    const num1 = toUint256WithFelts("1");
    const num2 = toUint256WithFelts("2");
    const num3 = toUint256WithFelts("3");
    const num4 = toUint256WithFelts("4");
    const num5 = toUint256WithFelts("5");
    console.log("num",num2)
    await acc1.invoke(contract, "mint", {
      to: toWallet,
      tokenId: num2,
    });
    const balance2 = (await contract.call("balanceOf", { owner: toWallet }))
    .balance;
    console.log("owner balance",balance2)

  expect(balance2).to.deep.equal(num2);


  });
});
