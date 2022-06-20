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

############
# MAPPINGS #
############

namespace TradeStatus:
    const Open = 1
    const Executed = 2
    const Cancelled = 3
end

namespace TradeType:
    const Sale = 1 
    const Swap = 2
end

##########
# EVENTS #
##########

@event
func SaleAction(trade : SaleTrade):
end

@event
func SwapAction(trade : SwapTrade):
end

@event
func BidAction(trade : Bid):
end

###########
# STORAGE #
###########

# Indexed list of sale trades
@storage_var
func sale_trades(idx : felt) -> (trade : SaleTrade):
end

# Indexed list of swap trades
@storage_var
func swap_trades(idx : felt) -> (trade : SwapTrade):
end


# Indexed list of all bids
@storage_var
func bids(idx : felt) -> (trade : Bid):
end

# Contract Address of ether used to purchase or sell items
@storage_var
func erc20_token_address() -> (address : felt):
end

# The current number of trades
@storage_var
func trade_counter() -> (value : felt):
end

# The current number of sale trades
@storage_var
func sale_trade_counter() -> (value : felt):
end

# The current number of swap trades
@storage_var
func swap_trade_counter() -> (value : felt):
end



###############
# CONSTRUCTOR #
###############

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
     owner : felt
):
    # erc20_token_address.write(erc20_address)
    Ownable_initializer(owner)
    sale_trade_counter.write(1)
    swap_trade_counter.write(1)
    trade_counter.write(1)
    return ()
end


###############
# LIST ITEM   #
###############

@external
func list_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _token_contract : felt,
    _token_id : Uint256,
    _expiration : felt,
    _price : felt, 
    _target_token_contract : felt,
    _target_token_id : Uint256,
    _trade_type :felt
    ):
    alloc_locals
    Pausable_when_not_paused()
    let (caller) = get_caller_address()
    let (contract_address) = get_contract_address()
    # let (owner_of) = IERC721.ownerOf(_token_contract, _token_id)
    # let (is_approved) = IERC721.isApprovedForAll(_token_contract, caller, contract_address)
    let (swap_trade_count) = swap_trade_counter.read()
    let (sale_trade_count) = sale_trade_counter.read()
    # assert owner_of = caller
    # assert is_approved = 1
    if _trade_type == 1:
        let _SaleTrade = SaleTrade(
            token_contract = _token_contract, 
            token_id = _token_id, 
            expiration = _expiration, 
            price = _price, 
            status = TradeStatus.Open,
            sale_trade_id = sale_trade_count)
        sale_trades.write(sale_trade_count,  _SaleTrade)
        sale_trade_counter.write(2)
        # TradeAction.emit(trade)
    else:
        let _SwapTrade =  SwapTrade(
            token_contract = _token_contract, 
            token_id = _token_id, 
            expiration = _expiration, 
            price = _price, 
            status = TradeStatus.Open,
            swap_trade_id = swap_trade_count,
            target_token_contract = _target_token_contract,
            target_token_id  =_target_token_id)
        swap_trades.write(swap_trade_count,_SwapTrade)
        swap_trade_counter.write(2)
        # TradeAction.emit(trade)
    end    
    return ()
end


###########
# GETTERS #
###########

@view
func get_sale_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(idx : felt) -> (
    trade : SaleTrade
):
    return sale_trades.read(idx)
end

@view
func get_swap_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(idx : felt) -> (
    trade : SwapTrade
):
    return swap_trades.read(idx)
end

@view
func get_sale_trade_counter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    sale_trade_counter : felt
):
    return sale_trade_counter.read()
end

@view
func get_swap_trade_counter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    sale_trade_counter : felt
):
    return swap_trade_counter.read()
end

# Returns a sale trades status
@view
func get_sale_trade_status{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    idx : felt
) -> (status : felt):
    let (trade) = sale_trades.read(idx)
    return (trade.status)
end
# Returns a swap trades status
@view
func get_swap_trade_status{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    idx : felt
) -> (status : felt):
    let (trade) = swap_trades.read(idx)
    return (trade.status)
end

# Returns a sale trades token
@view
func get_sale_trade_token_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    idx : felt
) -> (token_id : Uint256):
    let (trade) = sale_trades.read(idx)
    return (trade.token_id)
end

# Returns a swap trades token
@view
func get_swap_trade_token_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    idx : felt
) -> (token_id : Uint256):
    let (trade) = swap_trades.read(idx)
    return (trade.token_id)
end

@view
func paused{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (paused : felt):
    let (paused) = Pausable_paused.read()
    return (paused)
end
