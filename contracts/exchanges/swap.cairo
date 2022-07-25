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
func _swap_trades(idx : felt) -> (trade : SwapTrade):
end

# The current number of sale trades
@storage_var
func _trade_counter() -> (value : felt):
end

# Indexed list of all bids of the listed item
@storage_var
func _bids(trade_id : felt, item_bid_id : felt) -> (trade : SwapBid):
end

# Number of bids made to the listed item
@storage_var
func _bid_to_item_counter(trade_id : felt) -> (value : felt):
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
        _bid_to_item_counter.write(1,1)
        return ()
    end

    ###############
    # TRADE FUNC. #
    ###############

    func list_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
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
        let(caller) = get_caller_address()
        let (owner_of) = IERC721.ownerOf(_token_contract, _token_id)
        let (is_approved) = IERC721.isApprovedForAll(_token_contract, caller, contract_address)
        let (swap_trade_count) = _trade_counter.read()
        assert owner_of = caller
        assert is_approved = 1
        
        let _SwapTrade = SwapTrade(
            owner = caller,
            token_contract = _token_contract, 
            token_id = _token_id, 
            expiration = _expiration, 
            price = _price, 
            status =TradeStatus.Open,
            swap_trade_id = swap_trade_count,
            target_token_contract = _target_token_contract,
            target_token_id = _target_token_id)
        _swap_trades.write(swap_trade_count,  _SwapTrade)
        _trade_counter.write(swap_trade_count + 1)
        SwapAction.emit(_SwapTrade)
    
        return ()
    end

    func swap_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (caller) = get_caller_address()
        let (contract_address) = get_contract_address()
        let (swap_trade) = _swap_trades.read(_trade_id)
        assert swap_trade.status = TradeStatus.Open

        # Check buyer and seller still has NFT
        assert_swap_buyer_seller(swap_trade)
        # Check expritaion time
        assert_check_expiration(_trade_id)

        # İf seller wants nft + eth  
        transfer_currency(swap_trade.owner, caller, swap_trade.price)
        # transfer item to buyer
        IERC721.transferFrom(swap_trade.token_contract, swap_trade.owner, caller, swap_trade.token_id)
        # # transfer item to seller
        IERC721.transferFrom(swap_trade.target_token_contract, caller, swap_trade.owner, swap_trade.target_token_id)

        let _SwapTrade = SwapTrade(
            owner = swap_trade.owner,
            token_contract = swap_trade.token_contract, 
            token_id = swap_trade.token_id, 
            expiration = swap_trade.expiration, 
            price = swap_trade.price, 
            status =TradeStatus.Executed,
            swap_trade_id = _trade_id,
            target_token_contract = swap_trade.target_token_contract,
            target_token_id = swap_trade.target_token_id
            )
        _swap_trades.write(_trade_id,_SwapTrade)
        SwapAction.emit(_SwapTrade)
    
        return ()
    end

    func update_listing{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt, _price : felt, _target_token_contract : felt, _target_token_id : Uint256
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (caller) = get_caller_address()
        
        let (swap_trade) = _swap_trades.read(_trade_id)
        let (owner_of) = IERC721.ownerOf(swap_trade.token_contract, swap_trade.token_id)
        
        assert owner_of = caller
        assert swap_trade.owner = caller
        assert swap_trade.status = TradeStatus.Open

        assert_check_expiration(_trade_id)

        let _SwapTrade = SwapTrade(
            swap_trade.owner,
            swap_trade.token_contract, 
            swap_trade.token_id, 
            swap_trade.expiration, 
            _price, 
            swap_trade.status,
            _trade_id,
            _target_token_contract,
            _target_token_id)
        _swap_trades.write(_trade_id,  _SwapTrade)
        SwapAction.emit(_SwapTrade)
    
        return ()
    end

    func cancel_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt
        ):
        alloc_locals
        Pausable_when_not_paused()
        let (caller) = get_caller_address()
     
        let (swap_trade) = _swap_trades.read(_trade_id)
        let (owner_of) = IERC721.ownerOf(swap_trade.token_contract, swap_trade.token_id)
        
        assert owner_of = caller
        assert swap_trade.owner = caller
        assert swap_trade.status = TradeStatus.Open

        # assert_check_expiration(_id)

        # Swap Trade close function   
        # TradeStatus.Cancelled if second parameter = 1
        # TradeStatus.Executed if second parameter = 2
        change_swap_trade_status(_trade_id, 1)
    
        return ()
    end

    func bid_to_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt,
        _bid_contract_address : felt,
        _bid_token_id : Uint256,
        _expiration : felt,
        _price : felt,
        _target_token_contract : felt,
        _target_token_id : Uint256
        ):

        alloc_locals
        Pausable_when_not_paused()

        let (contract_address) = get_contract_address()
        let(caller) = get_caller_address()

        let (owner_of) = IERC721.ownerOf(_bid_contract_address, _bid_token_id)        
        let (is_approved) = IERC721.isApprovedForAll(_bid_contract_address, caller, contract_address)
        assert owner_of = caller
        assert is_approved = 1
        
        let (bid_to_item_counter) = _bid_to_item_counter.read(_trade_id)
        let (swap_trade) = _swap_trades.read(_trade_id)
        
        let _SwapBid = SwapBid(
            trade_id = _trade_id,
            bid_owner = caller,
            bid_contract_address = _bid_contract_address, 
            bid_token_id = _bid_token_id, 
            expiration = _expiration, 
            price = _price, 
            status = TradeStatus.Open,
            target_nft_owner = swap_trade.owner,
            target_token_contract = swap_trade.token_contract,
            target_token_id = swap_trade.token_id,
            item_bid_id = bid_to_item_counter)

        _bids.write(_trade_id, bid_to_item_counter,  _SwapBid)
        _bid_to_item_counter.write(_trade_id, bid_to_item_counter + 1)
        SwapBidAction.emit(_SwapBid)
    
        return ()
    end

    func accept_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt,
        _bid_id : felt,
        ):

        alloc_locals
        Pausable_when_not_paused()

        let(caller) = get_caller_address()
        let (swap_trade) = _swap_trades.read(_trade_id)
        let (swap_bid) = _bids.read(_trade_id, _bid_id)
        let (owner_of) = IERC721.ownerOf(swap_trade.token_contract, swap_trade.token_id)
        
        assert owner_of = caller
        assert swap_trade.owner = caller
        assert swap_trade.status = TradeStatus.Open
        assert swap_bid.status = TradeStatus.Open
        
        # Check expritaion time
        assert_check_expiration(_trade_id)

        # İf seller wants nft + eth  
        transfer_currency(swap_trade.owner,swap_bid.bid_owner, swap_bid.price )
        # transfer item to seller from bidder
        IERC721.transferFrom(swap_trade.token_contract, swap_trade.owner, swap_bid.bid_owner, swap_trade.token_id)
        # # transfer item to bidder from seller
        IERC721.transferFrom(swap_bid.bid_contract_address, swap_bid.bid_owner, caller, swap_bid.bid_token_id)

        # Swap Trade Bid close function
        # TradeStatus.Cancelled if second parameter = 1
        # TradeStatus.Executed if second parameter = 2
        change_swap_bid_status(_trade_id,_bid_id, 2)  

        # Swap Trade  close function   
        # TradeStatus.Cancelled if second parameter = 1
        # TradeStatus.Executed if second parameter = 2
        change_swap_trade_status(_trade_id, 2)
        return ()
    end

    func cancel_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt,
        _bid_id : felt,
        ):

        alloc_locals
        Pausable_when_not_paused()

        let(caller) = get_caller_address()
        let (swap_bid) = _bids.read(_trade_id, _bid_id)
        let (owner_of) = IERC721.ownerOf(swap_bid.bid_contract_address, swap_bid.bid_token_id)
        
        assert owner_of = caller
        assert swap_bid.bid_owner = caller
        assert swap_bid.status = TradeStatus.Open

        # Swap Trade Bid cancel function
        # TradeStatus.Cancelled if second parameter = 1
        # TradeStatus.Executed if second parameter = 2
        change_swap_bid_status(_trade_id,_bid_id, 1)  
    
        return ()
    end


    ###########
    # GETTERS #
    ###########

    func trade{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(_trade_id : felt) -> (trade: SwapTrade):
        let (trade) = _swap_trades.read(_trade_id)
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
        _trade_id : felt
        ) -> (status : felt):
        let (trade) = _swap_trades.read(_trade_id)
        return (trade.status)
    end

    # Returns a trades token
    func get_trade_token_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt
        ) -> (token_id : Uint256):
        let (trade) = _swap_trades.read(_trade_id)
        return (trade.token_id)
    end

    func bid{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(_trade_id : felt, _bid_id : felt) -> (trade: SwapBid):
        let (bid) = _bids.read(_trade_id,_bid_id)
        return (bid)
    end

     func get_bid_count{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(_trade_id : felt) -> (bid_count : felt):
        let (bid_count) = _bid_to_item_counter.read(_trade_id)
        return (bid_count)
    end

    
    @view
    func get_all_bids{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr: felt
    }(trade_id : felt ) -> (bids_ptr_len: felt, bids_ptr: SwapBid*):

        alloc_locals
        let (bids_count) = Swap_Trade.get_bid_count(trade_id)

        let (local bids_ptr: SwapBid*) = alloc()

        get_bids(
            trade_id=trade_id,
            bids_count=bids_count,
            bids_ptr_len=0,
            bids_ptr=bids_ptr
        )
        
        return (bids_count, bids_ptr)
    end

    func get_bids{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr: felt
    }(
        trade_id: felt,
        bids_count: felt,
        bids_ptr_len: felt,
        bids_ptr: SwapBid*
    ):

        if bids_ptr_len == bids_count:
            return ()
        end

        let (bid) = Swap_Trade.bid(
            trade_id,
            bids_ptr_len + 1
        )

        assert [bids_ptr] = bid

        get_bids(
            trade_id=trade_id,
            bids_count=bids_count,
            bids_ptr_len=bids_ptr_len + 1,
            bids_ptr=bids_ptr + SwapBid.SIZE
        )

        return ()

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

# If the bid owner cancels the bid or the bid is closed, the status changes
func change_swap_bid_status{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _trade_id : felt, 
    _bid_id : felt, 
    _status : felt
    ):
    let (swap_bid) =  _bids.read(_trade_id,_bid_id)

    let _SwapBid = SwapBid(
        trade_id = _trade_id,
        bid_owner = swap_bid.bid_owner,
        bid_contract_address = swap_bid.bid_contract_address, 
        bid_token_id = swap_bid.bid_token_id, 
        expiration = swap_bid.expiration, 
        price = swap_bid.price, 
        status = _status,
        target_nft_owner = swap_bid.target_nft_owner,
        target_token_contract = swap_bid.target_token_contract,
        target_token_id = swap_bid.target_token_id,
        item_bid_id = swap_bid.item_bid_id)

    _bids.write(_trade_id, _bid_id,  _SwapBid)
    SwapBidAction.emit(_SwapBid)

    return ()
end

# If the trade owner cancels the listing or the trade is closed, the status changes
func change_swap_trade_status{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _trade_id : felt,
    _status : felt
    ):
    let (swap_trade) = _swap_trades.read(_trade_id)

    let _SwapTrade = SwapTrade(
        owner = swap_trade.owner,
        token_contract = swap_trade.token_contract, 
        token_id = swap_trade.token_id, 
        expiration = swap_trade.expiration, 
        price = swap_trade.price, 
        status =_status,
        swap_trade_id = _trade_id,
        target_token_contract = swap_trade.target_token_contract,
        target_token_id = swap_trade.target_token_id
        )
    _swap_trades.write(_trade_id,_SwapTrade)
    SwapAction.emit(_SwapTrade)

    return ()
end

func assert_check_expiration{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _trade_id : felt
    ):
    let (block_timestamp) = get_block_timestamp()
    let (trade) = _swap_trades.read(_trade_id)
    # check trade expiration within
    assert_nn_le(block_timestamp, trade.expiration)

    return ()
end

func transfer_currency{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    seller : felt, buyer : felt, price : felt
    ):
    alloc_locals
    let (is_zero) = uint256_le(Uint256(price,0), Uint256(0, 0))
    if is_zero == 0:
        let (caller) = get_caller_address()
        let (currency) = erc20_token_address.read()
        let (buyer_balance : Uint256) = IERC20.balanceOf(currency,buyer)
        let (balance) = uint_to_felt(buyer_balance)
        assert_nn_le(price, balance)

        # let (allowance : Uint256) =  IERC20.allowance(caller,contract_address)
        # assert_nn_le(swap_trade.price, balance)

        # eth transfer to seller
        IERC20.transferFrom(currency, buyer, seller, Uint256(price, 0))
        return ()
    end
    return()
end

func assert_swap_buyer_seller{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (_swap_trade: SwapTrade):
    alloc_locals
    let (caller) = get_caller_address()
    let (contract_address) = get_contract_address()
    let (seller_item_owner) = IERC721.ownerOf(_swap_trade.token_contract, _swap_trade.token_id)
    let (buyer_item_owner) = IERC721.ownerOf(_swap_trade.target_token_contract , _swap_trade.target_token_id)
    assert seller_item_owner = _swap_trade.owner
    assert buyer_item_owner = caller

    let (seller_approve) = IERC721.isApprovedForAll(_swap_trade.token_contract, _swap_trade.owner, contract_address)
    let (buyer_approve) =  IERC721.isApprovedForAll(_swap_trade.target_token_contract, caller, contract_address)
    assert seller_approve = buyer_approve

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
