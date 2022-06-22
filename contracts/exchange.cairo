# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)
from starkware.cairo.common.math import assert_nn_le, unsigned_div_rem
from starkware.cairo.common.uint256 import Uint256, uint256_le

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from openzeppelin.token.erc721.interfaces.IERC721 import IERC721

from openzeppelin.access.ownable import Ownable_initializer, Ownable_only_owner
from openzeppelin.security.pausable import (
    Pausable_paused,
    Pausable_pause,
    Pausable_unpause,
    Pausable_when_not_paused,
)

from contracts.utils.structs import SaleTrade, SwapTrade, SaleBid, SwapBid
from contracts.sale import Sale_Trade

###########
# STORAGE #
###########

# The current number of trades
@storage_var
func trade_counter() -> (value : felt):
end

###############
# CONSTRUCTOR #
###############

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
     owner : felt,
     _erc20_address : felt,
):
    # erc20_token_address.write(erc20_address)
    Ownable_initializer(owner)
    Sale_Trade.initializer(owner,_erc20_address)
    trade_counter.write(1)
    return ()
end


###############
# LIST ITEM   #
###############

@external
func open_sale_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _token_contract : felt,
    _token_id : Uint256,
    _expiration : felt,
    _price : felt
    ):
    alloc_locals
    Pausable_when_not_paused()
    let (caller) =  get_caller_address()
    let (contract_address) = get_contract_address()
    # let (owner_of) = IERC721.ownerOf(_token_contract, _token_id)
    # let (is_approved) = IERC721.isApprovedForAll(_token_contract, caller, contract_address)
    # assert owner_of = caller
    # assert is_approved = 1
    
    Sale_Trade.list_item(
        caller,
        _token_contract, 
        _token_id, 
        _expiration, 
        _price
        )
 
    return ()
end

@external
func execute_sale_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _id : felt
    ):
    alloc_locals
    Pausable_when_not_paused()
    
    Sale_Trade.buy_item(_id)
 
    return ()
end



###########
# GETTERS #
###########

@view
func get_sale_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(_id : felt) -> (
    trade : SaleTrade
):
    let (trade : SaleTrade) = Sale_Trade.trade(_id)
    return (trade)
end

@view
func get_sale_trade_counter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    _trade_counter : felt
):
    let (trade_counter) = Sale_Trade.trade_counter()
    return (trade_counter)
end

@view
func paused{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (paused : felt):
    let (paused) = Pausable_paused.read()
    return (paused)
end
