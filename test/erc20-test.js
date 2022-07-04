//we import expect to test values
const { expect } = require("chai");
// These two lines allow us to play with our testnet and access our deployed contract 
const { starknet } = require("hardhat");
const { number, uint256 } = require("starknet");

const { StarknetContract, StarknetContractFactory } = require("hardhat/types/runtime");

const { Account } = require("@shardlabs/starknet-hardhat-plugin/dist/src/account");


describe("ERC20 Test Cases", function () {

  this.timeout(300_000);
  let contract;
  let acc1;
  let acc2;
  let acc3;
  let owner;
  let receipt;

  before(async function () {
    function toUint256WithFelts(num) {
        const n = uint256.bnToUint256(num);
        return {
          low: BigInt(n.low.toString()),
          high: BigInt(n.high.toString()),
        };
      }
    acc1 = await starknet.deployAccount("OpenZeppelin");
    acc2 = await starknet.deployAccount("OpenZeppelin");
    acc3 = await starknet.deployAccount("OpenZeppelin");
    console.log("Deployed acc1 address: ", acc1.starknetContract.address);
    console.log("Deployed acc2 address: ", acc2.starknetContract.address);
    console.log("Deployed acc3 address: ", acc3.starknetContract.address);

    const name = starknet.shortStringToBigInt("TestToken");
    const symbol = starknet.shortStringToBigInt("tst");
    const decimal = starknet.shortStringToBigInt("18")
    const initial_supply =toUint256WithFelts("25")
    
    owner =BigInt(acc1.starknetContract.address)
    receipt = BigInt(acc1.starknetContract.address)
    const contractFactory = await starknet.getContractFactory("ERC20");

    contract = await contractFactory.deploy({
      name,
      symbol,
      decimal,
      initial_supply,
      receipt,
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
    this.timeout(300_000);


    const balance2 = (await contract.call("getCallerAddress"));
    console.log("owner balance",balance2)


  });
});
