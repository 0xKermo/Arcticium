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
from contracts.exchanges.sale import Sale_Trade
from contracts.exchanges.swap import Swap_Trade

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
    Ownable_initializer(owner)
    Swap_Trade.initializer(owner,_erc20_address)
    Sale_Trade.initializer(owner,_erc20_address)
    trade_counter.write(1)
    return ()
end

############################
#          LIST ITEM       #
###########################

##############
# SALE TRADE #
##############

@external
func open_sale_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _token_contract : felt,
    _token_id : Uint256,
    _expiration : felt,
    _price : felt, 
    _owner_address : felt
    ):
    alloc_locals
    Pausable_when_not_paused()    
    Sale_Trade.list_item(
        _owner_address,
        _token_contract, 
        _token_id, 
        _expiration, 
        _price
        )
 
    return ()
end

@external
func execute_sale_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _id : felt,  _owner_address : felt
    ):
    alloc_locals
    Pausable_when_not_paused()
    
    Sale_Trade.buy_item(_id,_owner_address)
 
    return ()
end

@external
func update_sale_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _id : felt, price : felt, _owner_address : felt
    ):
    alloc_locals
    Pausable_when_not_paused()
    
    Sale_Trade.update_price(_id, price, _owner_address)
 
    return ()
end

@external
func cancel_sale_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _id : felt, _owner_address : felt
    ):
    alloc_locals
    Pausable_when_not_paused()
    
    Sale_Trade.cancel_listing(_id,_owner_address)
 
    return ()
end

##############
# SWAP TRADE #
##############

@external
func open_swap_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _token_contract : felt,
    _token_id : Uint256,
    _expiration : felt,
    _price : felt, 
    _target_token_contract : felt,
    _target_token_id : Uint256
    ):
    alloc_locals
    Pausable_when_not_paused()    
    Swap_Trade.list_item(
        _token_contract, 
        _token_id, 
        _expiration, 
        _price,
        _target_token_contract,
        _target_token_id
        )
 
    return ()
end

@external
func execute_swap_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _id : felt
    ):
    alloc_locals
    Pausable_when_not_paused()
    
    Swap_Trade.swap_item(_id)
 
    return ()
end

@external
func update_swap_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _id : felt,
    price : felt,
    _target_token_contract : felt,
    _target_token_id : Uint256
    ):
    alloc_locals
    Pausable_when_not_paused()
    
    Swap_Trade.update_listing(_id, price,_target_token_contract,_target_token_id)
 
    return ()
end

@external
func cancel_swap_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _id : felt
    ):
    alloc_locals
    Pausable_when_not_paused()
    
    Swap_Trade.cancel_trade(_id)
 
    return ()
end

##############
# SWAP BİD #
##############

@external
func open_swap_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _trade_id : felt,
    _bid_contract_address : felt,
    _bid_token_id : Uint256,
    _expiration : felt, 
    _price : felt,
    _target_token_contract : felt,
    _target_token_id : Uint256
    ):
    alloc_locals
    Swap_Trade.bid_to_item(
    _trade_id, 
    _bid_contract_address, 
    _bid_token_id, 
    _expiration,
    _price,
    _target_token_contract,
    _target_token_id
    )
 
    return ()
end

@external
func cancel_swap_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _trade_id : felt,
    _bid_id : felt
    ):
    alloc_locals

    Swap_Trade.cancel_bid(
    _trade_id, 
    _bid_id
    )
    return ()
end

@external
func accept_swap_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _trade_id : felt,
    _bid_id : felt
    ):
    alloc_locals    
    Swap_Trade.accept_bid(
    _trade_id, 
    _bid_id
    )
    return ()
end

#######################
#       GETTERS      #
######################

##############
# SALE GET.  #
##############
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

##############
# SWAP GET.  #
##############

@view
func get_swap_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(_id : felt) -> (
    trade : SwapTrade
):
    let (trade : SwapTrade) = Swap_Trade.trade(_id)
    return (trade)
end

@view
func get_swap_trade_counter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    trade_counter : felt
    ):
    let (trade_counter) = Swap_Trade.trade_counter()
    return (trade_counter)
end

@view
func get_swap_item_bid_count{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(_trade_id : felt) -> (
    bid_count : felt
    ):
    let (bid_count) = Swap_Trade.get_bid_count(_trade_id)
    return (bid_count)
end

@view
func get_swap_item_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(_trade_id : felt, _bid_id : felt) -> (
    bid : SwapBid
    ):
    let (bid) = Swap_Trade.bid(_trade_id,_bid_id )
    return (bid)
end

@view
func get_swap_item_bids{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(_trade_id : felt) -> (
    bids_len : felt, bids : SwapBid*
    ):
    let (bids_len,bids) = Swap_Trade.get_all_bids(_trade_id )
    return (bids_len, bids)
end


##############
#   COMMON   #
##############
@view
func paused{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (paused : felt):
    let (paused) = Pausable_paused.read()
    return (paused)
end
