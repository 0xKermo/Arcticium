%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem
from starkware.starknet.common.syscalls import storage_read, storage_write
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem,uint256_mul,uint256_add
from starkware.starknet.common.syscalls import ( get_contract_address,)

# The maximum amount of each token that belongs to the AMM.
const BALANCE_UPPER_BOUND = 2 ** 64

#ERC20 contract address
const TOKEN_TYPE_A = 1 #ERC20A
const TOKEN_TYPE_B = 2 #ERC20B
#Test User Account and Pool Account
const user_account= 3 #user account

# Ensure the user's balances are much smaller than the pool's balance.
const POOL_UPPER_BOUND = 2 ** 30
const ACCOUNT_BALANCE_BOUND = 1073741  # 2**30 // 1000.

@contract_interface
namespace IERC20:
    func balanceOf(account: felt) -> (balance: Uint256):
    end
    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt):
    end
    func approve(spender: felt, amount: Uint256) -> (success: felt):
    end


end

# A map from account and token type to the corresponding balance of that account.

@storage_var
func account_balance(account_id : felt, token_type: felt) -> (
    balance : Uint256
):
end

# A map from token type to the corresponding balance of the pool.
@storage_var
func pool_balance(token_type : felt) -> (balance : Uint256):
end

func modify_account_balance{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(account_id: felt, token_type: felt):
    let (amount) = IERC20.balanceOf(
         contract_address=token_type,
         account=account_id
    )
    #tempvar new_balance = amount
    #assert_nn_le(new_balance, BALANCE_UPPER_BOUND - 1)
    account_balance.write(account_id=account_id,token_type=token_type,value=amount)
    return ()
end

# Returns the account's balance for the given token.
@view
func get_account_token_balance{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(account_id: felt, token_type: felt) -> (balance: Uint256):
    let (amount) = IERC20.balanceOf(
         contract_address=token_type,
         account=account_id
    )
   return (amount)
end

func set_pool_token_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_type: felt
):
    let (pool_contract_address) = get_contract_address()
    let (balance) = IERC20.balanceOf(
         contract_address=token_type,
         account=pool_contract_address,
    )
    #assert_nn_le(balance, BALANCE_UPPER_BOUND - 1)
    pool_balance.write(token_type, balance)
    return ()
end

@view
func get_pool_token_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_type: felt
) -> (balance: Uint256):
    let (pool_contract_address) = get_contract_address()
    let (balance) = IERC20.balanceOf(
         contract_address=token_type,
         account=pool_contract_address,
    )
    return (balance)
end

# Swaps tokens between the given account and the pool.
func do_swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
     token_from : felt, token_to : felt, amount_from : Uint256,
) -> (amount_to : Uint256):
    alloc_locals

    # Get pool balance.
    let (amm_from_balance) = get_pool_token_balance(token_type=token_from)
    let (amm_to_balance) = get_pool_token_balance(token_type=token_to)
    let (from_mul_balance,_) = uint256_mul(amm_to_balance ,amount_from)
    let (balance_add_from,_) = uint256_add(amm_from_balance, amount_from)
    # Calculate swap amount.
    let (local amount_to, _) = uint256_unsigned_div_rem(
        from_mul_balance, balance_add_from
    )

    # Update token_from balances.
    let (pool_contract_address) = get_contract_address()
    IERC20.approve(contract_address=token_from,spender=pool_contract_address, amount=amount_from)
    IERC20.transferFrom(contract_address=token_from,sender=user_account,recipient=pool_contract_address,amount=amount_from)
    modify_account_balance(account_id=user_account, token_type=token_from)
    set_pool_token_balance(token_type=token_from)
    # Update token_to balances.
    IERC20.transferFrom(contract_address=token_from,sender=pool_contract_address, recipient=user_account,amount=amount_from)
    modify_account_balance(account_id=user_account, token_type=token_to)
    set_pool_token_balance(token_type=token_to)
    return (amount_to=amount_to)
end

func get_opposite_token(token_type : felt) -> (t : felt):
    if token_type == TOKEN_TYPE_A:
        return (TOKEN_TYPE_B)
    else:
        return (TOKEN_TYPE_A)
    end
end

# Swaps tokens between the given account and the pool.
@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt, token_from : felt, amount_from : felt
) -> (amount_to : felt):
    # Verify that token_from is either TOKEN_TYPE_A or TOKEN_TYPE_B.
    assert (token_from - TOKEN_TYPE_A) * (token_from - TOKEN_TYPE_B) = 0

    # Check requested amount_from is valid.
    assert_nn_le(amount_from, BALANCE_UPPER_BOUND - 1)
    # Check user has enough funds.
    let (account_from_balance) = get_account_token_balance(
        account_id=account_id, token_type=token_from
    )
    assert_le(amount_from, account_from_balance)

    let (token_to) = get_opposite_token(token_type=token_from)
    let (amount_to) = do_swap(
        account_id=account_id, token_from=token_from, token_to=token_to, amount_from=amount_from
    )

    return (amount_to=amount_to)
end

# Adds demo tokens to the given account.
@external
func start_account{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
):
    modify_account_balance(account_id=user_account, token_type=TOKEN_TYPE_A)
    modify_account_balance(account_id=user_account, token_type=TOKEN_TYPE_B)
    return ()
end

# Until we have LPs, for testing, we'll need to initialize the AMM somehow.
@external
func start_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
):
  
    set_pool_token_balance(token_type=TOKEN_TYPE_A)
    set_pool_token_balance(token_type=TOKEN_TYPE_B)

    return ()
end
 
@view
func call_balanceOf{syscall_ptr : felt*, range_check_ptr}() -> (balance : Uint256):
    let (amount) = IERC20.balanceOf(
        contract_address=1254314629700364791828439516032305930923791567227608279460087677062508711704,
        account = 2249418062284905328603548186940662585303569235097685892892509878425842577826
    )
    return (amount)
end
