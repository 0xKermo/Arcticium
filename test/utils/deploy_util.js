const { expect } = require("chai");
const { starknet } = require("hardhat");
const {
  StarknetContract,
  StarknetContractFactory,
} =require("hardhat/types/runtime");
const { toUint256WithFelts } =require("./util");
const { number, uint256 } =require("starknet");

export async function deployERC721(
  owner,
  erc721Type
) {
  const name = starknet.shortStringToBigInt("ARCNFT");
  const symbol = starknet.shortStringToBigInt("ARC");

  // Deploy the contract

  const contractFactory =
    await starknet.getContractFactory(erc721Type);
  const contract = await contractFactory.deploy({
    name,
    symbol,
    owner,
  });

  console.log("Successfully deployed");

  // Call getter functions
  const n = (await contract.call("name")).name;
  const s = (await contract.call("symbol")).symbol;


  // Expect to match inputs
  expect(n).to.deep.equal(name);
  expect(s).to.deep.equal(symbol);

  console.log(`Deployed contract to ${contract.address}`);
  return contract;
}

export async function deployERC20(
  owner,
  erc20Type
) {
  const name = starknet.shortStringToBigInt("ArcCoin");
  const symbol = starknet.shortStringToBigInt("ARC");
  const cap = toUint256WithFelts("1000000");
  const decimals = BigInt(18);

  // Deploy the contract
  const contractFactory =
    await starknet.getContractFactory(erc20Type);
  const contract = await contractFactory.deploy({
    name,
    symbol,
    decimals,
    owner,
    cap,
  });

  // Call getter functions
  const n = (await contract.call("name")).name;
  const s = (await contract.call("symbol")).symbol;
  const d = (await contract.call("decimals")).decimals;
  const o = (await contract.call("owner")).owner;
  const c = (await contract.call("cap")).cap;

  // Expect to match inputs
  expect(n).to.deep.equal(name);
  expect(s).to.deep.equal(symbol);
  expect(d).to.deep.equal(decimals);
  expect(o).to.deep.equal(owner);
  expect(c).to.deep.equal(cap);

  // Optional decoding to original types
  console.log(`Deployed contract to ${contract.address} with args:`);
  console.log("name: ", starknet.bigIntToShortString(n));
  console.log("symbol: ", starknet.bigIntToShortString(s));
  console.log("decimals: ", d.toString());
  console.log("owner: ", number.toHex(o.toString()));
  console.log("cap: ", uint256.uint256ToBN(c).toString());
  return contract;
}
