import { Account, Provider, Contract, ContractFactory, ec } from "starknet";


const ERC721_ARTIFACT =
  readFileSync(__dirname + "/artifacts/token/ERC721/ERC721.json").toString("ascii");

  
const deploy = async () => {
  const DEVNET_PROVIDER_OPTIONS = {
    baseUrl: 'http://127.0.0.1:5050/'
  }
  console.log("Started deployment");
  const provider = new Provider(DEVNET_PROVIDER_OPTIONS);

  const ctc = await provider.deployContract({
    contract: ERC721_ARTIFACT,
    constructorCalldata: ["32762643845375604",
    "1951286868",
    "3525570178991347606243544905170370909634811577571717640310903706096836710426"

    ]
  });
  await provider.waitForTransaction(ctc.transaction_hash)
  if (ctc.address === undefined)
    throw new Error("Address undefined");

  // "Balance" represent our smart contract.
  const contractFactory = await starknet.getContractFactory("ERC721");
  const contract = await contractFactory.deploy({ initial_balance: 0 });
  
  console.log("Deployed at", contract.address);

}


deploy()