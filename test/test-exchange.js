//we import expect to test values
const { expect } = require("chai");
// These two lines allow us to play with our testnet and access our deployed contract 
const { starknet } = require("hardhat");
const { number, uint256 } = require("starknet");

const { StarknetContract, StarknetContractFactory } = require("hardhat/types/runtime");

// import library to transform string <>decimal
const { Account } = require("@shardlabs/starknet-hardhat-plugin/dist/src/account");
// const  { deployERC721 } =  require("./utils/deploy_util");

describe("exchange Test Cases", function () {

  this.timeout(300_000);
  let contract;
  let erc721;
  let erc20;
  let owner;
  let target_token_contract;

  before(async function () {

    owner = await starknet.deployAccount("OpenZeppelin");
    erc721 = await starknet.deployAccount("OpenZeppelin");
    erc20 = await starknet.deployAccount("OpenZeppelin");
    target_token_contract = await starknet.deployAccount("OpenZeppelin");
    console.log("Deployed acc1 address: ", acc1.starknetContract.address);
    console.log("Deployed erc721 address: ", erc721.starknetContract.address);
    console.log("Deployed erc20 address: ", erc20.starknetContract.address);
    console.log("Deployed target token contract address: ", target_token_contract.starknetContract.address);

    const contractFactory = await starknet.getContractFactory("exchange");
    
    owner = BigInt(acc1.starknetContract.address)
    erc20 = BigInt(erc20.starknetContract.address)
    erc721 = BigInt(erc721.starknetContract.address)
    target_token_contract = BigInt(target_token_contract.starknetContract.address)

    contract = await contractFactory.deploy({
      owner,
      erc20
    });

    console.log("Successfully deployed", contract.address);
  });

  it("Should create a trade and get this informations.", async function () {
    function toUint256WithFelts(num) {
      const n = uint256.bnToUint256(num);
      return {
        low: BigInt(n.low.toString()),
        high: BigInt(n.high.toString()),
      };
    }
    const token_contract = BigInt(erc721.starknetContract.address);
    const num0 = toUint256WithFelts("0");
    const num1 = toUint256WithFelts("1");
    const num2 = toUint256WithFelts("2");
    const num3 = toUint256WithFelts("3");
    const num4 = toUint256WithFelts("4");
    const num5 = toUint256WithFelts("5");
    console.log("num",num2)
    await acc1.invoke(contract, "open_trade", {
      _token_contract: token_contract,
      _token_id: num2,
      _expiration: 1210981217,
      _price: num5,
      _target_token_contract: target_token_contract,
      _target_token_id: num5,
      _trade_type: 1
    });
  //   const balance2 = (await contract.call("balanceOf", { owner: toWallet }))
  //   .balance;
  //   console.log("owner balance",balance2)

  // expect(balance2).to.deep.equal(num2);


  });
});
