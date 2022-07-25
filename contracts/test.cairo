%lang starknet

## @title AMM1 Oracle
## @dev Implements IOracle for AMM1

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import (assert_not_zero, assert_le)



@storage_var
func all_pool_addresses(id: felt) -> (contract_address : felt):
end

@storage_var
func pool_counter() -> (id: felt):
end

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}():
    pool_counter.write(1)
    return ()
end

@external
func add_pool{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
} (pool_address: felt):

  let (idcount) = pool_counter.read()
  all_pool_addresses.write(idcount, pool_address)
  pool_counter.write(idcount + 1)
  return ()
end

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
        total_number_of_pools=total_number_of_pools - 1,
        pools_ptr_len=0,
        pools_ptr=pools_ptr
    )
    
    return (total_number_of_pools, pools_ptr)
end

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