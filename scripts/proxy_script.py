import asyncio
import json

from starknet_py.contract import Contract
from starknet_py.net import AccountClient
from starknet_py.net.gateway_client import GatewayClient

# Local network
from starknet_py.net.models import StarknetChainId
from starknet_py.transactions.declare import make_declare_tx
from starkware.starknet.compiler.compile import get_selector_from_name


async def setup_accounts():
    local_network_client = GatewayClient("https://alpha4.starknet.io")
    # Deploys an account on devnet and returns an instance
    account_client = await AccountClient.create_account(
        client=local_network_client, chain=StarknetChainId.TESTNET
    )
    return local_network_client, account_client


async def declare_contract(admin_client, contract_src):
    declare_tx = make_declare_tx(compilation_source=[contract_src])
    return await admin_client.declare(declare_tx)


async def setup_contracts(network_client, admin_client):
    # Declare implementation contract
    declaration_result = await declare_contract(
        admin_client, "contracts/exchange.cairo"
    )
    print("declaration address",declaration_result)
    # exchange = await Contract.deploy(
    #     network_client,
    #     compilation_source=["contracts/exchange.cairo"],
    #     constructor_args=[ ],
    # )
    # # Wait for the transaction to be accepted
    # await exchange.wait_for_acceptance()
    # exchange = exchange.deployed_contract
    # print("exchange address",exchange.address)
    # Deploy proxy and call initializer in the constructor
    deployment_result = await Contract.deploy(
        network_client,
        compilation_source=["contracts/Proxy.cairo"],
        constructor_args=[
            3525570178991347606243544905170370909634811577571717640310903706096836710426,
            declaration_result.class_hash,
            get_selector_from_name("initialize"),
            [3525570178991347606243544905170370909634811577571717640310903706096836710426],
        ],
    )
    # Wait for the transaction to be accepted
    await deployment_result.wait_for_acceptance()
    proxy = deployment_result.deployed_contract
    print("proxy address",proxy.address)
    # Redefine the ABI so that `call` and `invoke` work
    with open("artifacts/abis/exchange.json", "r") as abi_file:
        implementation_abi = json.load(abi_file)
    proxy = Contract(
        address=proxy.address,
        abi=implementation_abi,
        client=admin_client,
    )
    return proxy


async def upgrade_proxy(admin_client, proxy_contract, new_contract_src):
    # Declare implementation contract
    declaration_result = await declare_contract(admin_client, new_contract_src)

    # Upgrade contract
    call = proxy_contract.functions["upgrade"].prepare(
        new_implementation=declaration_result.class_hash
    )
    await admin_client.execute(calls=call, max_fee=0)
    # If you change the ABI, update the `proxy_contract` here.


async def main():
    local_network_client, account_client = await setup_accounts()
    proxy_contract = await setup_contracts(local_network_client, account_client)

    (proxy_admin,) = await proxy_contract.functions["getAdmin"].call()
    # assert account_client.address == proxy_admin
    print("The proxy admin was set to our account:", hex(proxy_admin))

    # Note that max_fee=0 is only possible on starknet-devnet.
    # When deploying on testnet, your account_client needs to have enough funds.
    # value_target = 0x123
    (count,) = await proxy_contract.functions["get_erc20_count"].call()
    print("count",count)


if __name__ == "__main__":
    asyncio.run(main())