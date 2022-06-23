# SPDX-License-Identifier: MIT

%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)
from starkware.cairo.common.math import assert_nn_le, unsigned_div_rem, assert_lt_felt
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

from contracts.utils.structs import SwapTrade, SwapBid

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
func SwapAction(trade : SwapTrade):
end

@event
func SwapBidAction(trade : SwapBid):
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
func _trades(idx : felt) -> (trade : SwapTrade):
end

# Indexed list of all bids
@storage_var
func bids(idx : felt) -> (trade : SwapBid):
end

# The current number of sale trades
@storage_var
func _trade_counter() -> (value : felt):
end


namespace Swap_Trade:

    #################
    # Constructor   #
    ################

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

    ###############
    # TRADE FUNC. #
    ###############

    func list_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _owner_address : felt,  
        _token_contract : felt,
        _token_id : Uint256,
        _expiration : felt,
        _price : felt,
        _target_token_contract : felt,
        _target_token_id : Uint256
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (contract_address) = get_contract_address()
        # let(caller) = get_caller_address()
        let (owner_of) = IERC721.ownerOf(_token_contract, _token_id)
        let (is_approved) = IERC721.isApprovedForAll(_token_contract, _owner_address, contract_address)
        let (swap_trade_count) = _trade_counter.read()
        assert owner_of = _owner_address
        assert is_approved = 1
        
        let _SwapTrade = SwapTrade(
            owner = _owner_address,
            token_contract = _token_contract, 
            token_id = _token_id, 
            expiration = _expiration, 
            price = _price, 
            status =TradeStatus.Open,
            swap_trade_id = swap_trade_count,
            target_token_contract = _target_token_contract,
            target_token_id = _target_token_id)
        _trades.write(swap_trade_count,  _SwapTrade)
        _trade_counter.write(swap_trade_count + 1)
        SwapAction.emit(_SwapTrade)
    
        return ()
    end

    func swap_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _id : felt,  _owner_address : felt
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (caller) = get_caller_address()

        let (swap_trade) = _trades.read(_id)
        
        assert swap_trade.status = TradeStatus.Open

        if swap_trade.price != 0:
            let (currency) = erc20_token_address.read()
            let (buyer_balance) = IERC20.balanceOf(currency,_owner_address)
            let(balance) = uint_to_felt(buyer_balance)
            assert_nn_le(swap_trade.price, balance)
            # transfer to seller
            IERC20.transferFrom(currency, caller, swap_trade.owner, Uint256(swap_trade.price, 0))
        
        end
        
        # assert_check_expiration(_id)

        
        # transfer item to buyer
        # IERC721.transferFrom(swap_trade.token_contract, swap_trade.owner, caller, swap_trade.token_id)
        # # transfer item to seller
        # IERC721.transferFrom(swap_trade.target_token_contract, caller, swap_trade.owner, swap_trade.target_token_id)

        let _SwapTrade = SwapTrade(
            owner = swap_trade.owner,
            token_contract = swap_trade.token_contract, 
            token_id = swap_trade.token_id, 
            expiration = swap_trade.expiration, 
            price = swap_trade.price, 
            status =TradeStatus.Executed,
            swap_trade_id = _id,
            target_token_contract = swap_trade.target_token_contract,
            target_token_id = swap_trade.target_token_id
            )
        _trades.write(_id,  _SwapTrade)
        SwapAction.emit(_SwapTrade)
    
        return ()
    end

    func update_listing{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _id : felt, _price : felt, _target_token_contract : felt, _target_token_id : Uint256, _owner_address : felt
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (caller) = get_caller_address()
        
        let (swap_trade) = _trades.read(_id)
        let (owner_of) = IERC721.ownerOf(swap_trade.token_contract, swap_trade.token_id)
        
        assert owner_of = _owner_address
        assert swap_trade.owner = caller
        assert swap_trade.status = TradeStatus.Open

        # assert_check_expiration(_id)

        let _SwapTrade = SwapTrade(
            swap_trade.owner,
            swap_trade.token_contract, 
            swap_trade.token_id, 
            swap_trade.expiration, 
            _price, 
            swap_trade.status,
            _id,
            _target_token_contract,
            _target_token_id)
        _trades.write(_id,  _SwapTrade)
        SwapAction.emit(_SwapTrade)
    
        return ()
    end

    func cancel_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _id : felt, _owner_address : felt
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (caller) = get_caller_address()
     
        let (swap_trade) = _trades.read(_id)
        let (owner_of) = IERC721.ownerOf(swap_trade.token_contract, swap_trade.token_id)
        
        assert owner_of = _owner_address
        assert swap_trade.owner = _owner_address
        assert swap_trade.status = TradeStatus.Open

        # assert_check_expiration(_id)

        let _SwapTrade = SwapTrade(
            swap_trade.owner,
            swap_trade.token_contract, 
            swap_trade.token_id, 
            swap_trade.expiration, 
            swap_trade.price, 
            TradeStatus.Cancelled,
            _id,
            swap_trade.target_token_contract,
            swap_trade.target_token_id)
        _trades.write(_id,  _SwapTrade)
        SwapAction.emit(_SwapTrade)
    
        return ()
    end

    ###########
    # GETTERS #
    ###########

    func trade{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(_id : felt) -> (trade: SwapTrade):
        let (trade) = _trades.read(_id)
        return (trade)
    end

    func trade_counter{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }() -> (trade_counter: felt):
        let (trade_counter) = _trade_counter.read()
        return (trade_counter)
    end

    # Returns a trades status
    func get_trade_status{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _id : felt
    ) -> (status : felt):
        let (trade) = _trades.read(_id)
        return (trade.status)
    end

    # Returns a trades token
    func get_trade_token_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _id : felt
    ) -> (token_id : Uint256):
        let (trade) = _trades.read(_id)
        return (trade.token_id)
    end

    ###########
    # SETTERS #
    ###########

    func set_currency_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _erc20_address : felt
    ) -> (success : felt):
        Ownable_only_owner()
        erc20_token_address.write(_erc20_address)
        return (1)
    end

    
    func pause{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
        Ownable_only_owner()
        Pausable_pause()
        return ()
    end

    
    func unpause{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
        Ownable_only_owner()
        Pausable_unpause()
        return ()
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
