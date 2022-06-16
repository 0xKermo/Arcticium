const { config } =require("hardhat");
const { number, uint256 } = require("starknet");
const { expect }= require("chai");

const type  = () =>{
  return(
  low,
  high
  )
};
export default type;

// export const ZERO_ADDRESS =
//   "0x0000000000000000000000000000000000000000000000000000000000000000";

// /**
//  * Retrieve address from a wallet
//  * @param myWallet
//  * @returns
//  */
// export function getAddressFromWallet(myWallet) {
//   const accounts = require(myWallet.accountPath +
//     "/starknet_open_zeppelin_accounts.json");
//   return accounts[NETWORK][myWallet.accountName].address;
// }

// /**
//  * To use uint256 with cairo, low and high fields must be felts (not sure if there is an library to help here)
//  * @param num
//  * @returns
//  */
// export function toUint256WithFelts(num) {
//   const n = uint256.bnToUint256(num);
//   return {
//     low: BigInt(n.low.toString()),
//     high: BigInt(n.high.toString()),
//   };
// }

// /**
//  * Used to reverse toUint256WithFelts
//  * @param uint256WithFelts
//  * @returns
//  */
// export const fromUint256WithFelts = (uint256WithFelts) =>{
//   return uint256.uint256ToBN({
//     low: uint256WithFelts.low.toString(),
//     high: uint256WithFelts.high.toString(),
//   });
// }

// /** Cairo Field Element Arrays allow for much bigger strings (up to 2^15 characters) and manipulation is implemented on-chain **/

// /**
//  * Splits a string into an array of short strings (felts). A Cairo short string (felt) represents up to 31 utf-8 characters.
//  * @param {string} str - The string to convert
//  * @returns {bigint[]} - The string converted as an array of short strings as felts
//  */
// export function strToFeltArr(str) {
//   const size = Math.ceil(str.length / 31);
//   const arr = Array(size);

//   let offset = 0;
//   for (let i = 0; i < size; i++) {
//     const substr = str.substring(offset, offset + 31).split("");
//     const ss = substr.reduce(
//       (memo, c) => memo + c.charCodeAt(0).toString(16),
//       ""
//     );
//     arr[i] = BigInt("0x" + ss);
//     offset += 31;
//   }
//   return arr;
// }

// /**
//  * Converts an array of utf-8 numerical short strings into a readable string
//  * @param {bigint[]} felts - The array of encoded short strings
//  * @returns {string} - The readable string
//  */
// export function feltArrToStr(felts){
//   return felts.reduce(
//     (memo, felt) => memo + Buffer.from(felt.toString(16), "hex").toString(),
//     ""
//   );
// }

// /**
//  * Expects a StarkNet transaction to fail
//  * @param {Promise<any>} transaction - The transaction that should fail
//  * @param {string} [message] - The message returned from StarkNet
//  */
// // eslint-disable-next-line @typescript-eslint/no-explicit-any
// export async function shouldFail(
//   transaction,
//   message= "Transaction rejected."
// ) {
//   try {
//     await transaction;
//     expect.fail("Transaction should fail");
//     // eslint-disable-next-line @typescript-eslint/no-explicit-any
//   } catch (err) {
//     expect(err.message).to.deep.contain(message);
//   }
// }

// /**
//  * Logs the error on call fail.
//  * Sometimes the error are not correctly displayed. This helper can help debug hard to find errors
//  * @param {() => Promise<void>} fn - The function to test
//  */
// export async function tryCatch(fn) {
//   try {
//     await fn();
//   } catch (e) {
//     console.error(e);
//     expect.fail("Test failed");
//   }
// }