# SPDX-License-Identifier: MIT

%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)
from starkware.cairo.common.math import assert_nn_le, unsigned_div_rem, assert_lt_felt,assert_not_zero
from starkware.cairo.common.uint256 import Uint256, uint256_le

from contracts.openzeppelin.access.ownable.library import Ownable
from contracts.openzeppelin.token.erc20.IERC20 import IERC20
from contracts.openzeppelin.token.erc721.IERC721 import IERC721


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
            
        ):
        Ownable.initializer(_owner_address)
        return ()
    end

    ###############
    # TRADE FUNC. #
    ###############

    func list_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _token_contract : felt,
        _token_id : Uint256,
        _expiration : felt,
        _currency_address : felt,
        _price : Uint256,
        _tradeType : felt,
        _target_token_contract : felt,
        _target_token_id : Uint256
        ):
        alloc_locals
        let (contractAddress) = get_contract_address()
        let(caller) = get_caller_address()
        let (ownerOf) = IERC721.ownerOf(_token_contract, _token_id)
        let (isApproved) = IERC721.isApprovedForAll(_token_contract, caller, contractAddress)
        let (swapTradeCount) = _trade_counter.read()
        
        with_attr error_message("Caller not owner"):
            assert ownerOf = caller
        end
        with_attr error_message("not Approved"):
            assert isApproved = 1
        end
                
        let _SwapTrade = SwapTrade(
            owner = caller,
            token_contract = _token_contract, 
            token_id = _token_id, 
            expiration = _expiration, 
            currency_address = _currency_address,
            price = _price, 
            status =TradeStatus.Open,
            swap_trade_id = swapTradeCount+1,
            trade_type = _tradeType,
            target_token_contract = _target_token_contract,
            target_token_id = _target_token_id)
        _swap_trades.write(swapTradeCount+1,  _SwapTrade)
        _trade_counter.write(swapTradeCount + 1)
        SwapAction.emit(_SwapTrade)
    
        return ()
    end

    func swap_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt
        ):
        alloc_locals
        let (caller) = get_caller_address()
        let (swapTrade) = _swap_trades.read(_trade_id)
        with_attr error_message("Trade not open"):
            assert swapTrade.status = TradeStatus.Open
        end

        # Check expritaion time
        assert_check_expiration(_trade_id)

        # İf seller wants nft + eth  
        transfer_currency(swapTrade.owner, caller, swapTrade.price, swapTrade.currency_address)
        # transfer item to buyer
        IERC721.transferFrom(swapTrade.token_contract, swapTrade.owner, caller, swapTrade.token_id)
        # # transfer item to seller
        IERC721.transferFrom(swapTrade.target_token_contract, caller, swapTrade.owner, swapTrade.target_token_id)

        let _SwapTrade = SwapTrade(
            owner = swapTrade.owner,
            token_contract = swapTrade.token_contract, 
            token_id = swapTrade.token_id, 
            expiration = swapTrade.expiration, 
            currency_address = swapTrade.currency_address,
            price = swapTrade.price, 
            status =TradeStatus.Executed,
            swap_trade_id = _trade_id,
            trade_type = swapTrade.trade_type,
            target_token_contract = swapTrade.target_token_contract,
            target_token_id = swapTrade.target_token_id
            )
        _swap_trades.write(_trade_id,_SwapTrade)
        SwapAction.emit(_SwapTrade)
    
        return ()
    end

    func update_listing{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt, _price : Uint256, _target_token_contract : felt, _target_token_id : Uint256
        ):
        alloc_locals
        let (caller) = get_caller_address()
        
        let (swapTrade) = _swap_trades.read(_trade_id)
        let (owner_of) = IERC721.ownerOf(swapTrade.token_contract, swapTrade.token_id)
        with_attr error_message("Caller not owner of token"):
            assert owner_of = caller
        end

        with_attr error_message("Caller not owner of trade"):
            assert swapTrade.owner = caller
        end

        with_attr error_message("Trade not open"):
            assert swapTrade.status = TradeStatus.Open
        end

        assert_check_expiration(_trade_id)

        let _SwapTrade = SwapTrade(
            swapTrade.owner,
            swapTrade.token_contract, 
            swapTrade.token_id, 
            swapTrade.expiration, 
            swapTrade.currency_address,
            _price, 
            swapTrade.status,
            _trade_id,
            swapTrade.trade_type,
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
        let (caller) = get_caller_address()
     
        let (swapTrade) = _swap_trades.read(_trade_id)
        let (owner_of) = IERC721.ownerOf(swapTrade.token_contract, swapTrade.token_id)
        
        with_attr error_message("Caller not owner of token"):
            assert owner_of = caller
        end

        with_attr error_message("Caller not owner of trade"):
            assert swapTrade.owner = caller
        end

        with_attr error_message("Trade not open"):
            assert swapTrade.status = TradeStatus.Open
        end

        # assert_check_expiration(_id)

        # Swap Trade close function   
        # TradeStatus.Cancelled if second parameter = 3
        # TradeStatus.Executed if second parameter = 2
        change_swap_trade_status(_trade_id, 3)
    
        return ()
    end

    func bid_to_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt,
        _bid_contract_address : felt,
        _bid_token_id : Uint256,
        _expiration : felt,
        _currency_address : felt,
        _price : Uint256,
        _target_token_contract : felt,
        _target_token_id : Uint256
        ):

        alloc_locals

        let (contractAddress) = get_contract_address()
        let(caller) = get_caller_address()

        let (ownerOf) = IERC721.ownerOf(_bid_contract_address, _bid_token_id)        
        let (isApproved) = IERC721.isApprovedForAll(_bid_contract_address, caller, contractAddress)
        with_attr error_message("Caller not owner of token"):
            assert ownerOf = caller
        end

        with_attr error_message("Token not approved"):
            assert isApproved = 1
        end

        let (itemBidCount) = _bid_to_item_counter.read(_trade_id)
        let (swapTrade) = _swap_trades.read(_trade_id)
        
        let _SwapBid = SwapBid(
            trade_id = _trade_id,
            bid_owner = caller,
            bid_contract_address = _bid_contract_address, 
            bid_token_id = _bid_token_id, 
            expiration = _expiration, 
            currency_address = _currency_address,
            price = _price, 
            status = TradeStatus.Open,
            target_nft_owner = swapTrade.owner,
            target_token_contract = swapTrade.token_contract,
            target_token_id = swapTrade.token_id,
            item_bid_id = itemBidCount+1)

        _bids.write(_trade_id, itemBidCount +1,  _SwapBid)
        _bid_to_item_counter.write(_trade_id, itemBidCount + 1)
        SwapBidAction.emit(_SwapBid)
    
        return ()
    end

    func accept_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _trade_id : felt,
        _bid_id : felt,
        ):

        alloc_locals

        let(caller) = get_caller_address()
        let (swapTrade) = _swap_trades.read(_trade_id)
        let (swapBid) = _bids.read(_trade_id, _bid_id)
        let (owner_of) = IERC721.ownerOf(swapTrade.token_contract, swapTrade.token_id)
        with_attr error_message("Caller not owner of token"):
            assert owner_of = caller
        end

        with_attr error_message("Caller not owner of trade"):
            assert swapTrade.owner = caller
        end

        with_attr error_message("Trade not open"):
            assert swapTrade.status = TradeStatus.Open
        end

        with_attr error_message("Bid not open"):
            assert swapBid.status = TradeStatus.Open
        end
        
        # Check expritaion time
        assert_check_expiration(_trade_id)

        # İf seller wants nft + eth  
        transfer_currency(swapTrade.owner,swapBid.bid_owner, swapBid.price,  swapBid.currency_address )
        # transfer item to seller from bidder
        IERC721.transferFrom(swapTrade.token_contract, swapTrade.owner, swapBid.bid_owner, swapTrade.token_id)
        # # transfer item to bidder from seller
        IERC721.transferFrom(swapBid.bid_contract_address, swapBid.bid_owner, caller, swapBid.bid_token_id)

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

        let(caller) = get_caller_address()
        let (swapBid) = _bids.read(_trade_id, _bid_id)
        let (ownerOf) = IERC721.ownerOf(swapBid.bid_contract_address, swapBid.bid_token_id)
        
        with_attr error_message("Caller not owner of token"):
            assert ownerOf = caller
        end

        with_attr error_message("Caller not owner of bid"):
            assert swapBid.bid_owner = caller
        end

        with_attr error_message("Bid not open"):
            assert swapBid.status = TradeStatus.Open
        end

        # Swap Trade Bid cancel function
        # TradeStatus.Cancelled if second parameter = 3
        # TradeStatus.Executed if second parameter = 2
        change_swap_bid_status(_trade_id,_bid_id, 3)  
    
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
        let (tradeCounter) = _trade_counter.read()
        return (tradeCounter)
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
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr : felt
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
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr : felt
        }(trade_id: felt,bids_count: felt,bids_ptr_len: felt,bids_ptr: SwapBid*):

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
    let (swapBid) =  _bids.read(_trade_id,_bid_id)

    let _SwapBid = SwapBid(
        trade_id = _trade_id,
        bid_owner = swapBid.bid_owner,
        bid_contract_address = swapBid.bid_contract_address, 
        bid_token_id = swapBid.bid_token_id, 
        expiration = swapBid.expiration, 
        currency_address = swapBid.currency_address,
        price = swapBid.price, 
        status = _status,
        target_nft_owner = swapBid.target_nft_owner,
        target_token_contract = swapBid.target_token_contract,
        target_token_id = swapBid.target_token_id,
        item_bid_id = swapBid.item_bid_id)

    _bids.write(_trade_id, _bid_id,  _SwapBid)
    SwapBidAction.emit(_SwapBid)

    return ()
end

# If the trade owner cancels the listing or the trade is closed, the status changes
func change_swap_trade_status{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _trade_id : felt,
    _status : felt
    ):
    let (swapTrade) = _swap_trades.read(_trade_id)

    let _SwapTrade = SwapTrade(
        owner = swapTrade.owner,
        token_contract = swapTrade.token_contract, 
        token_id = swapTrade.token_id, 
        expiration = swapTrade.expiration, 
        currency_address = swapTrade.currency_address,
        price = swapTrade.price, 
        status =_status,
        swap_trade_id = _trade_id,
        trade_type = swapTrade.trade_type,
        target_token_contract = swapTrade.target_token_contract,
        target_token_id = swapTrade.target_token_id
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
    _seller : felt, _buyer : felt, _price :Uint256, _currency_address : felt
    ):
    alloc_locals
    let (isZero) = uint256_le(_price, Uint256(0, 0))
    if isZero == 0:
        let (caller) = get_caller_address()
        let (balance : Uint256) = IERC20.balanceOf(_currency_address,_buyer)
        let (res) =  uint256_le(_price,balance)
        with_attr error_message("insufficient balance"):
            assert res = 1
        end
        # let (allowance : Uint256) =  IERC20.allowance(caller,contract_address)
        # assert_nn_le(swap_trade.price, balance)

        # eth transfer to seller
        IERC20.transferFrom(_currency_address, _buyer, _seller, _price)
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
