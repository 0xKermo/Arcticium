//we import expect to test values
const { expect } = require("chai");
// These two lines allow us to play with our testnet and access our deployed contract 
const { starknet } = require("hardhat");
const { number, uint256 } = require("starknet");

const { StarknetContract, StarknetContractFactory } = require("hardhat/types/runtime");

// import library to transform string <>decimal
const { Account, OpenZeppelinAccount } = require("@shardlabs/starknet-hardhat-plugin/dist/src/account");
// const  { deployERC721 } =  require("./utils/deploy_util");
function toUint256WithFelts(num) {
    const n = uint256.bnToUint256(num);
    return {
        low: BigInt(n.low.toString()),
        high: BigInt(n.high.toString()),
    };
}

function fromUint256WithFelts(uint256WithFelts) {
    return uint256.uint256ToBN({
        low: uint256WithFelts.low.toString(),
        high: uint256WithFelts.high.toString(),
    });
}

describe("exchange Test Cases", function () {

    this.timeout(900_000);
    let addr1;
    let addr2;
    let addr3;
    let contract;
    let erc721Contract;
    let erc20Contract;
    let owner;
    let receipt;
    let exchangeContract;

    let _addr1;
    
    before(async function () {
        _addr1 = await starknet.deployAccount("OpenZeppelin");
        addr2 = await starknet.deployAccount("OpenZeppelin");
        addr3 = await starknet.deployAccount("OpenZeppelin");
        owner = await starknet.deployAccount("OpenZeppelin");
        receipt = await starknet.deployAccount("OpenZeppelin")
        target_token_contract = await starknet.deployAccount("OpenZeppelin");

        console.log("Deployed addr1 address: ", _addr1.starknetContract.address);
        console.log("Deployed owner address: ", owner.starknetContract.address);
        console.log("Deployed addr2 address: ", addr2.starknetContract.address);
        console.log("Deployed addr3 address: ", addr3.starknetContract.address);
        console.log("Deployed receipt address: ", receipt.starknetContract.address);
        console.log("Deployed target token contract address: ", target_token_contract.starknetContract.address);

        addr1 = BigInt(_addr1.starknetContract.address)
        addr2 = BigInt(addr2.starknetContract.address)
        addr3 = BigInt(addr3.starknetContract.address)
        owner = BigInt(owner.starknetContract.address)
        target_token_contract = BigInt(target_token_contract.starknetContract.address)
        
        /// - -- -- - -- - -     ERC721  - - -- - - -- - -/////
        let name = starknet.shortStringToBigInt("ArcswapNFT");
        let symbol = starknet.shortStringToBigInt("ARCNFT");
        const Erc721contractFactory = await starknet.getContractFactory("ERC721");
        erc721Contract = await Erc721contractFactory.deploy({
            name,
            symbol,
            owner
        });

        console.log("Successfully deployed Nft Contract", erc721Contract.address);

        /// - -- -- - -- - -     ERC20  - - -- - - -- - -/////
         name = starknet.shortStringToBigInt("TestToken");
         symbol = starknet.shortStringToBigInt("tst");
        const decimals = BigInt(18)
        const initial_supply =toUint256WithFelts("25")
        
        recipient = BigInt(receipt.starknetContract.address)
        const Erc20contractFactory = await starknet.getContractFactory("ERC20");
    
        erc20Contract = await Erc20contractFactory.deploy({
          name,
          symbol,
          decimals,
          initial_supply,
          recipient,
          owner
        });

        console.log("Successfully deployed ERC20 Contract", erc20Contract.address);


        ////// - - - - - -- - - -- -    Exchange   - - ----- - - -- - ///////////// 
        const ExcContractFactory = await starknet.getContractFactory("exchange");
        const _erc20_address = BigInt(erc20Contract.address)
        exchangeContract = await ExcContractFactory.deploy({
        owner,
        _erc20_address
        });

        console.log("Successfully deployed Exchange Contract", exchangeContract.address);

    });

    it("Should create a trade and get this informations.", async function () {

        this.timeout(300_000);
        const num1 = toUint256WithFelts("1");

        await _addr1.invoke(erc721Contract, "mint", {
            to: addr1,
            tokenId : num1
        })
        const balance2 = (await erc721Contract.call("balanceOf", { owner: addr1 }))
        .balance;
        console.log("Erc721 balance",balance2)

        const price = 1
        console.log("price")
        const token_contract = BigInt(erc20Contract.address)
        console.log("token_contract")

        await _addr1.invoke(contract, "open_swap_trade", {
            _token_contract: token_contract,
            _token_id: num1,
            _expiration: 1210981217,
            _price: price,
            _owner_address : addr1,
            _target_token_contract: target_token_contract,
            _target_token_id: num1,
        });
        const trade_ = (await erc721Contract.call("get_swap_trade", { owner: 1 }));
        console.log("trade", trade_)

    });
});
