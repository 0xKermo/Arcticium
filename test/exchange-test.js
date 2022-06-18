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

    this.timeout(600_000);
    let addr1;
    let contract;
    let erc721;
    let erc20;
    let owner;
    let token_contract;
    let target_token_contract;
    function toUint256WithFelts(num) {
        const n = uint256.bnToUint256(num);
        return {
            low: BigInt(n.low.toString()),
            high: BigInt(n.high.toString()),
        };
    }

    function fromUint256WithFelts  (uint256WithFelts) {
        return uint256.uint256ToBN({
          low: uint256WithFelts.low.toString(),
          high: uint256WithFelts.high.toString(),
        });
      }
      
    before(async function () {
        addr1 = await starknet.deployAccount("OpenZeppelin");
        owner = await starknet.deployAccount("OpenZeppelin");
        erc721 = await starknet.deployAccount("OpenZeppelin");
        erc20 = await starknet.deployAccount("OpenZeppelin");
        token_contract = await starknet.deployAccount("OpenZeppelin");
        target_token_contract = await starknet.deployAccount("OpenZeppelin");
        console.log("Deployed addr1 address: ", addr1.starknetContract.address);
        console.log("Deployed owner address: ", owner.starknetContract.address);
        console.log("Deployed erc721 address: ", erc721.starknetContract.address);
        console.log("Deployed erc20 address: ", erc20.starknetContract.address);
        console.log("Deployed token contract address: ",token_contract.starknetContract.address);
        console.log("Deployed target token contract address: ", target_token_contract.starknetContract.address);
        const contractFactory = await starknet.getContractFactory("exchange");

        addr1 = BigInt(addr1.starknetContract.address)
        owner = BigInt(owner.starknetContract.address)
        erc20 = BigInt(erc20.starknetContract.address)
        erc721 = BigInt(erc721.starknetContract.address)
        token_contract = BigInt(
            token_contract.starknetContract.address
        )
        target_token_contract = BigInt(target_token_contract.starknetContract.address)
        contract = await contractFactory.deploy({
            owner        });

        console.log("Successfully deployed", contract.address);
    });

    it("Should create a trade and get this informations.", async function () {

      
        const num0 = toUint256WithFelts("0");
        const num1 = toUint256WithFelts("1");
        const num2 = toUint256WithFelts("2");
        const num3 = toUint256WithFelts("3");
        const num4 = toUint256WithFelts("4");
        const num5 = toUint256WithFelts("5");
        const price = 1
        console.log("num", num2)
        await contract.invoke(contract, "open_trade", {
            _token_contract: token_contract,
            _token_id: num2,
            _expiration: 1210981217,
            _price: price,
            _target_token_contract: target_token_contract,
            _target_token_id: num5,
            _trade_type: 1
        });
          const trade_ = (await contract.call("balanceOf", { owner: toWallet }));
          console.log("trade",trade_)

    });
});
