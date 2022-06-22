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

############
# MAPPINGS #
############

namespace TradeStatus:
    const Open = 1
    const Executed = 2
    const Cancelled = 3
end

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

# Contract Address of ether used to purchase or sell items
@storage_var
func erc20_token_address() -> (address : felt):
end

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
            _owner_address : felt,
            _erc20_address : felt,
            
        ):
        Ownable_initializer(_owner_address)
        erc20_token_address.write(_erc20_address)
        _trade_counter.write(1)
        return ()
    end

    func list_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _owner_address : felt,  
        _token_contract : felt,
        _token_id : Uint256,
        _expiration : felt,
        _price : felt
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (contract_address) = get_contract_address()
        # let (owner_of) = IERC721.ownerOf(_token_contract, _token_id)
        # let (is_approved) = IERC721.isApprovedForAll(_token_contract, caller, contract_address)
        let (sale_trade_count) = _trade_counter.read()
        # assert owner_of = caller
        # assert is_approved = 1
        
        let _SaleTrade = SaleTrade(
            owner = _owner_address,
            token_contract = _token_contract, 
            token_id = _token_id, 
            expiration = _expiration, 
            price = _price, 
            status =TradeStatus.Open,
            sale_trade_id = sale_trade_count)
        _trades.write(sale_trade_count,  _SaleTrade)
        _trade_counter.write(sale_trade_count + 1)
        SaleAction.emit(_SaleTrade)
    
        return ()
    end

    func buy_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _id : felt,  
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (caller) = get_caller_address()
        let (currency) = erc20_token_address.read()
        # let (buyer_balance) = IERC20.balanceOf(caller)
        
        let (sale_trade) = _trades.read(_id)
        
        assert sale_trade.status = TradeStatus.Open
        assert_nn_le(price, uint_to_felt(buyer_balance))
        # assert_check_expiration(_id)
        assert sale_trade.owner = caller
         # transfer to seller
        IERC20.transferFrom(currency, caller, sale_trade.owner, Uint256(sale_trade.price, 0))

        # transfer item to buyer
        IERC721.transferFrom(sale_trade.token_contract, sale_trade.owner, caller, sale_trade.token_id)

        let _SaleTrade = SaleTrade(
            owner = sale_trade.owner,
            token_contract = sale_trade.token_contract, 
            token_id = sale_trade.token_id, 
            expiration = sale_trade.expiration, 
            price = sale_trade.price, 
            status =TradeStatus.Executed,
            sale_trade_id = _id)
        _trades.write(_id,  _SaleTrade)
        SaleAction.emit(_SaleTrade)
    
        return ()
    end

    func update_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _id : felt,  _price : felt
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (caller) = get_caller_address()
        # let (owner_of) = IERC721.ownerOf(_token_contract, _token_id)
        # assert owner_of = caller
        let (sale_trade) = _trades.read(_id)
        assert sale_trade.owner = caller
        
        assert sale_trade.status = TradeStatus.Open

        # assert_check_expiration(_id)

        let _SaleTrade = SaleTrade(
            sale_trade.owner,
            sale_trade.token_contract, 
            sale_trade.token_id, 
            sale_trade.expiration, 
            _price, 
            TradeStatus.Executed,
            _id)
        _trades.write(_id,  _SaleTrade)
        SaleAction.emit(_SaleTrade)
    
        return ()
    end

    func cancel_listing{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _id : felt,  _price : felt
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (caller) = get_caller_address()
        # let (owner_of) = IERC721.ownerOf(_token_contract, _token_id)
        # assert owner_of = caller
        let (sale_trade) = _trades.read(_id)
        assert sale_trade.owner = caller
        
        assert sale_trade.status = TradeStatus.Open

        # assert_check_expiration(_id)

        let _SaleTrade = SaleTrade(
            sale_trade.owner,
            sale_trade.token_contract, 
            sale_trade.token_id, 
            sale_trade.expiration, 
            sale_trade.price, 
            TradeStatus.Cancelled,
            _id)
        _trades.write(_id,  _SaleTrade)
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

###########
# HELPERS #
###########

func assert_check_expiration{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _id : felt
):
    let (block_timestamp) = get_block_timestamp()
    let (trade) = _trades.read(_id)
    # check trade expiration within
    assert_nn_le(block_timestamp, trade.expiration)

    return ()
end


func uint_to_felt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (value: Uint256) -> (value: felt):
    assert_lt_felt(value.high, 2**123)
    return (value.high * (2 ** 128) + value.low)
end
