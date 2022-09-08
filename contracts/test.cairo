%lang starknet

## @title AMM1 Oracle
## @dev Implements IOracle for AMM1

from contracts.openzeppelin.ownable import Ownable
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import (
    assert_lt, assert_not_zero, assert_not_equal)
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (
    Uint256, uint256_lt, uint256_add, uint256_unsigned_div_rem, 
    uint256_mul)

## TYPES
################################################################################

struct Amm1PathOpt:
    # Tokens
    member path_0: felt
    member path_1: felt
    member path_2: felt
    member path_3: felt 
end
 
## AMM INTERFACE
################################################################################

@contract_interface
namespace AMM_1:
    func get_pool_token_balance(token_type: felt) -> (balance: Uint256):
    end
end

## STORAGE VARIABLES
################################################################################

@storage_var
func _pool_addresses(token_1: felt, token_2: felt) -> (pool_address: felt):
end

@storage_var
func all_pool_addresses(id: felt) -> (contract_address : felt):
end

@storage_var
func pool_counter() -> (id: felt):
end
## CONSTRUCTOR
################################################################################

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(caller: felt):
    Ownable.initializer(caller) 
    pool_counter.write(1)
    return ()
end

## EXTERNAL
################################################################################

## @notice Adds a new pool
## @dev Only owner
## @param token_1: Address of token 1
## @param token_2: Address of token 2
## @param pool_address: Contract address for pool of token 1<>token 2
@external
func add_pool{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token_1: felt, token_2: felt, pool_address: felt):

  _pool_addresses.write(token_1, token_2, pool_address)
  let (idcount) = pool_counter.read()
  all_pool_addresses.write(idcount, pool_address)
  pool_counter.write(idcount + 1)
  return ()
end

## Pool Addresses - View
##############################################################################
@view
func get_pool{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(id: felt) -> (pool_address: felt):
    let (pool_address) = all_pool_addresses.read(id)
    return (pool_address)
end

@view
func get_pool_count{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (pool_count: felt):
    let (pool_count) = pool_counter.read()
    return (pool_count)
end

@view
func get_all_pools{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr: felt
}() -> (pools_ptr_len: felt, pools_ptr: felt*):

    alloc_locals
    let (total_number_of_pools) = pool_counter.read()

    let (local pools_ptr: felt*) = alloc()

    get_pools(
        total_number_of_pools=total_number_of_pools,
        pools_ptr_len=0,
        pools_ptr=pools_ptr
    )
    
    return (total_number_of_pools, pools_ptr)
end

## Pool Addresses - Internal
##############################################################################
func get_pools{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr: felt
}(
    total_number_of_pools: felt,
    pools_ptr_len: felt,
    pools_ptr: felt*
):

    if pools_ptr_len == total_number_of_pools:
        return ()
    end

    let (pool_address) = all_pool_addresses.read(
        pools_ptr_len+1)

    assert [pools_ptr] = pool_address

    get_pools(
        total_number_of_pools=total_number_of_pools,
        pools_ptr_len=pools_ptr_len + 1,
        pools_ptr=pools_ptr +1
    )

    return ()

end

## IORACLE 
################################################################################

## TODO: RENAME to get_amt_out
## @notice Gets price from the AMM1
## @dev This will change for each unique AMM we'll have
## @dev Calculates the rate as RESERVE_OUT / (RESERVE_IN + AMT_IN)
@view
func get_amt_out{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(amt_in: Uint256, token_in: felt, token_out: felt) -> (rate: Uint256):
    alloc_locals
    with_attr error_message("Same token provided"):
        assert_not_equal(token_in, token_out)
    end
    let (token_1: felt, token_2: felt) = sort_tokens(token_in, token_out)

    # Query for the pool
    let (pool_address: felt) = _pool_addresses.read(token_1, token_2)
    with_attr error_message("No such pool exists"):
        assert_not_zero(pool_address) 
    end

    # Get balances for each token
    let (token_in_balance: Uint256) = AMM_1.get_pool_token_balance(
        contract_address=pool_address,
        token_type=token_in)
    let (tok_in_nn: felt) = uint256_lt(Uint256(0,0), token_in_balance)
    assert tok_in_nn = 1

    let (token_out_balance: Uint256) = AMM_1.get_pool_token_balance(
        contract_address=pool_address,
        token_type=token_out)
    let (tok_out_nn: felt) = uint256_lt(Uint256(0,0), token_in_balance)
    assert tok_out_nn = 1
    local syscall_ptr: felt* = syscall_ptr
  
    # Calculate price
    # Assume AMT_IN * TOKEN_IN_RESERVE won't overflow
    # Assume AMT_IN * RATE won't overflow
    let (rate_0: Uint256, carry: felt) = uint256_add(amt_in, token_in_balance)
    assert carry = 0
    let (rate_1: Uint256, rem: Uint256) = uint256_unsigned_div_rem(
        token_out_balance, rate_0)
    assert rem.low = 0
    let (rate_2: Uint256, rem: Uint256) = uint256_mul(rate_1, amt_in)
    assert rem.low = 0
    return (rate=rate_2)
end

## @notice Gets amount out for a fixed amount in and a path
## @dev Assumes paths are left-aligned (ie somethings like [a,0,b,c] is not 
## possible). Instead it should be [a,b,0,c]. (1)
@view
func get_amt_out_through_path{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(amt_in: Uint256, opt: Amm1PathOpt) -> (amt_out: Uint256):
    # Must be impossible
    if opt.path_0 == 0:
        return (amt_out=Uint256(0,0))
    end

    if opt.path_3 == 0:
        return (amt_out=Uint256(0,0))
    end

    if opt.path_1 != 0:
        let (amt_out_0: Uint256) = get_amt_out(amt_in, opt.path_0, opt.path_1)

        if opt.path_2 != 0:
            let (amt_out_1: Uint256) = get_amt_out(amt_out_0, opt.path_1, opt.path_2)
            let (amt_out_2: Uint256) = get_amt_out(amt_out_1, opt.path_2, opt.path_3)
            return (amt_out=amt_out_2)
        else: 
            let (amt_out_0: Uint256) = get_amt_out(amt_in, opt.path_0, opt.path_3)
            return (amt_out=amt_out_0) 
        end

    # Due to the assumption (1) we can conclude path_2 is also 0, we'll go to
    # the dst_token directly
    else:
        let (amt_out_0: Uint256) = get_amt_out(amt_in, opt.path_0, opt.path_3)
        return (amt_out=amt_out_0) 
    end 
end

## @note We could also have a get_amt_in_through_path that calculates an
## amount in for a fixed output but it is extra work and mostly done on the
## router level.

@view
@raw_output
func sample_sells_from_amm1{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    opts_len: felt, opts: Amm1PathOpt*,
    amts_len: felt, amts: felt*,
    src_token: felt, dst_token: felt
) -> (
    retdata_size: felt, retdata: felt*
):
    alloc_locals
    let (retdata: felt*) = alloc()

    # If no path options are provided, return empty
    if opts_len == 0:
        return (0, retdata)
    end

    # If path options' length and amounts' length don't match return empty
    if opts_len != amts_len:
        return (0, retdata)
    end

    let (best_path: Amm1PathOpt) = _find_best_path(
        opts_len, opts, amts_len, amts)
    
    _fill_dst_amts(
        idx=0, amts_len=opts_len, amts=amts, opt=best_path, retdata=retdata)

    return (amts_len*2, retdata)
end

func _fill_dst_amts{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(idx:felt, amts_len: felt, amts: felt*, opt: Amm1PathOpt, retdata: felt*):
    if idx == amts_len:
        return ()
    end

    let (amt_thr_path: Uint256) = get_amt_out_through_path(
        amt_in=Uint256(amts[idx], 0), opt=opt)
    assert retdata[idx*2    ] = amt_thr_path.low
    assert retdata[idx*2 + 1] = amt_thr_path.high

    return _fill_dst_amts(idx+1, amts_len, amts, opt, retdata)
end

func _find_best_path{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    opts_len: felt, opts: Amm1PathOpt*,
    amts_len: felt, amts: felt*
) -> (best_path: Amm1PathOpt): 
    return __find_best_path(
        idx=0, best_idx=0, best_bought=Uint256(0,0),
        opts_len=opts_len, opts=opts,
        amts_len=amts_len, amts=amts)
end

func __find_best_path{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    idx: felt, best_idx: felt, best_bought: Uint256,
    opts_len: felt, opts: Amm1PathOpt*,
    amts_len: felt, amts: felt*
) -> (best_path: Amm1PathOpt):
    alloc_locals
    if idx == opts_len:
        return (best_path=opts[best_idx])
    end

    let (local bought_amt: Uint256) = get_amt_out_through_path(
        amt_in=Uint256(amts[idx], 0), 
        opt=opts[idx])

    local opts: Amm1PathOpt* = opts

    let (is_best: felt) = uint256_lt(best_bought, bought_amt)
    if is_best == 1:
        return __find_best_path(
            idx+1, idx, bought_amt, opts_len, opts, amts_len, amts)
    else:
        return __find_best_path(
            idx+1, best_idx, best_bought, opts_len, opts, amts_len, amts)
    end 
end

## HELPERS
################################################################################

## @notice Takes in & out tokens and returns them in an ascending order
## @dev Assumption: token_in != token_out
func sort_tokens{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token_in: felt, token_out: felt) -> (token_1: felt, token_2: felt):
    assert_not_zero(token_out)

    # a < b == a <= (b-1)
    let (in_lt_out: felt) = is_le(token_in, token_out-1)
    if in_lt_out == 1:
      return (token_in, token_out)
    else:
      return (token_out, token_in)
    end
end
