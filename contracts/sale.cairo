# SPDX-License-Identifier: MIT

%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
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

from contracts.utils.structs import SaleTrade, SaleBid

##########
# EVENTS #
##########

@event
func SaleAction(trade : SaleTrade):
end

@event
func SaleBidAction(trade : SaleBid):
end

###########
# STORAGE #
###########

# Indexed list of sale trades
@storage_var
func _trades(idx : felt) -> (trade : SaleTrade):
end

# Indexed list of all bids
@storage_var
func bids(idx : felt) -> (trade : SaleBid):
end

# The current number of sale trades
@storage_var
func _trade_counter() -> (value : felt):
end

###############
# LIST ITEM   #
###############
namespace Sale_Trade:

    #
    # Constructor
    #

    func initializer{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(
            owner: felt,
            
        ):
        Ownable_initializer(owner)
        _trade_counter.write(1)
        return ()
    end

    func list_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _owner_address : felt,  
        _token_contract : felt,
        _token_id : Uint256,
        _expiration : felt,
        _price : felt, 
        _trade_status : felt
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (caller) = get_caller_address()
        let (contract_address) = get_contract_address()
        # let (owner_of) = IERC721.ownerOf(_token_contract, _token_id)
        # let (is_approved) = IERC721.isApprovedForAll(_token_contract, caller, contract_address)
        let (sale_trade_count) = _trade_counter.read()
        # assert owner_of = caller
        # assert is_approved = 1
        
        let _SaleTrade = SaleTrade(
            owner_address = caller,
            token_contract = _token_contract, 
            token_id = _token_id, 
            expiration = _expiration, 
            price = _price, 
            status =_trade_status,
            sale_trade_id = sale_trade_count)
        _trades.write(sale_trade_count,  _SaleTrade)
        _trade_counter.write(sale_trade_count + 1)
        SaleAction.emit(_SaleTrade)
    
        return ()
    end


    func trade_counter{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }() -> (trade_counter: felt):
        let (trade_counter) = _trade_counter.read()
        return (trade_counter)
    end

    func trade{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(_id : felt) -> (trade: SaleTrade):
        let (trade) = _trades.read(_id)
        return (trade)
    end
end