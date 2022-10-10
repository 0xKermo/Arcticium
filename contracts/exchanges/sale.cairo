// SPDX-License-Identifier: MIT

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

from contracts.utils.structs import SaleTrade, SaleBid

//###########
// MAPPINGS #
//###########

namespace TradeStatus {
    const Open = 1;
    const Executed = 2;
    const Cancelled = 3;
}

//#########
// EVENTS #
//#########

@event
func SaleAction(trade: SaleTrade) {
}

@event
func SaleBidAction(trade: SaleBid) {
}

//##########
// STORAGE #
//##########


// Indexed list of sale trades
@storage_var
func _trades(idx: felt) -> (trade: SaleTrade) {
}

// Indexed list of all bids
@storage_var
func _bids(idx: felt) -> (trade: SaleBid) {
}

// Number of bids made to the listed item
@storage_var
func _bid_to_item_counter(trade_id: felt) -> (value: felt) {
}

// The current number of sale trades
@storage_var
func _trade_counter() -> (value: felt) {
}

namespace Sale_Trade {
    //################
    // Constructor   #
    //###############

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _owner_address: felt
    ) {
        Ownable_initializer(_owner_address);
        return ();
    }

    //##############
    // TRADE FUNC. #
    //##############

    func list_item{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _token_contract: felt,
        _token_id: Uint256,
        _expiration: felt,
        _currency_address: felt,
        _price: felt,
        _trade_type: felt,

    ) {
        alloc_locals;
        Pausable_when_not_paused();
        let (contract_address) = get_contract_address();
        let(caller) = get_caller_address()
        let (owner_of) = IERC721.ownerOf(_token_contract, _token_id);
        let (is_approved) = IERC721.isApprovedForAll(
            _token_contract, caller, contract_address
        );
        let (sale_trade_count) = _trade_counter.read();
        assert owner_of = caller;
        assert is_approved = 1;

        let _SaleTrade = SaleTrade(
            sale_trade_id=sale_trade_count + 1,
            owner=caller,
            token_contract=_token_contract,
            token_id=_token_id,
            expiration=_expiration,
            currency_address=_currency_address,
            price=_price,
            status=TradeStatus.Open,
            trade_type = _trade_type,

        );
        _trades.write(sale_trade_count, _SaleTrade);
        _trade_counter.write(sale_trade_count + 1);
        SaleAction.emit(_SaleTrade);

        return ();
    }

    func buy_item{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _trade_id: felt, _owner_address: felt
    ) {
        alloc_locals;
        Pausable_when_not_paused();
        let (caller) = get_caller_address();
        let (currency) = erc20_token_address.read();
        let (buyer_balance) = IERC20.balanceOf(currency, _owner_address);
        let (balance) = uint_to_felt(buyer_balance);
        let (saleTrade) = _trades.read(_trade_id);
        with_attr error_message("Trade not open") {
            assert saleTrade.status = TradeStatus.Open;
        }
        assert_nn_le(saleTrade.price, balance);
        assert_check_expiration(_trade_id)
        with_attr error_message("Wrong Trade!") {
            assert saleTrade.owner = _owner_address;

        }
        // transfer to seller
        IERC20.transferFrom(
            currency, _owner_address, saleTrade.owner, Uint256(saleTrade.price, 0)
        );

        // transfer item to buyer
        IERC721.transferFrom(
            saleTrade.token_contract, saleTrade.owner, _owner_address, saleTrade.token_id
        );

        let _SaleTrade = SaleTrade(
            sale_trade_id=_trade_id,
            owner=saleTrade.owner,
            token_contract=saleTrade.token_contract,
            token_id=saleTrade.token_id,
            expiration=saleTrade.expiration,
            currency_address=saleTrade.currency_address,
            price=saleTrade.price,
            status=TradeStatus.Executed,
            trade_type = saleTrade._trade_type,
        );
        _trades.write(_id, _SaleTrade);
        SaleAction.emit(_SaleTrade);

        return ();
    }

    func update_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _trade_id: felt, _price: felt, _owner_address: felt
    ) {
        alloc_locals;
        Pausable_when_not_paused();
        let (caller) = get_caller_address();

        let (saleTrade) = _trades.read(_trade_id);
        let (owner_of) = IERC721.ownerOf(saleTrade.token_contract, saleTrade.token_id);

        assert owner_of = _owner_address;
        assert saleTrade.owner = caller;
        assert saleTrade.status = TradeStatus.Open;

        // assert_check_expiration(_id)

        let _SaleTrade = SaleTrade(
            saleTrade.owner,
            saleTrade.token_contract,
            saleTrade.token_id,
            saleTrade.expiration,
            saleTrade.currency_address,
            _price,
            TradeStatus.Executed,
            _trade_id,
            saleTrade.trade_type
        );
        _trades.write(_id, _SaleTrade);
        SaleAction.emit(_SaleTrade);

        return ();
    }

    func cancel_listing{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _trade_id: felt, _owner_address: felt
    ) {
        alloc_locals;
        Pausable_when_not_paused();
        let (caller) = get_caller_address();

        let (saleTrade) = _trades.read(_trade_id);
        let (owner_of) = IERC721.ownerOf(saleTrade.token_contract, saleTrade.token_id);

        assert owner_of = _owner_address;
        assert saleTrade.owner = _owner_address;
        assert saleTrade.status = TradeStatus.Open;

        assert_check_expiration(_trade_id)

        let _SaleTrade = SaleTrade(
            saleTrade.owner,
            saleTrade.token_contract,
            saleTrade.token_id,
            saleTrade.expiration,
            saleTrade.price,
            TradeStatus.Cancelled,
            _trade_id,
        );
        _trades.write(_trade_id, _SaleTrade);
        SaleAction.emit(_SaleTrade);

        return ();
    }

    func bid_to_item{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _trade_id: felt,
        _expiration: felt,
        _currency_address: felt,
        _bid_price: Uint256,
    ) {
        alloc_locals;

        let (contractAddress) = get_contract_address();
        let (caller) = get_caller_address();

        with_attr error_message("Listing time expired") {
            assert_check_expiration(_trade_id);
        }


        let (itemBidCount) = _bid_to_item_counter.read(_trade_id);
        let (saleTrade) = _trades.read(_trade_id);

        let _SaleBid = SaleBid(
            trade_id=_trade_id,
            bid_owner=caller,
            bid_contract_address=saleTrade.token_contract,
            bid_token_id=saleTrade.token_id,
            expiration=_expiration,
            currency_address=_currency_address,
            bid_price=_bid_price,
            status=TradeStatus.Open,
            item_bid_id=itemBidCount + 1,
        );

        _bids.write(_trade_id, itemBidCount + 1, _SaleBid);
        _bid_to_item_counter.write(_trade_id, itemBidCount + 1);
        SaleBidAction.emit(_SaleBid);

        return ();
    }

    func accept_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _trade_id: felt, _bid_id: felt
    ) {
        alloc_locals;

        let (caller) = get_caller_address();
        let (saleTrade) = _trades.read(_trade_id);
        let (saleBid) = _bids.read(_trade_id, _bid_id);
        let (owner_of) = IERC721.ownerOf(saleBid.token_contract, saleBid.token_id);
        with_attr error_message("Caller not owner of token") {
            assert owner_of = caller;
        }

        with_attr error_message("Caller not owner of trade") {
            assert saleTrade.owner = caller;
        }

        with_attr error_message("Trade not open") {
            assert saleTrade.status = TradeStatus.Open;
        }

        with_attr error_message("Bid not open") {
            assert saleBid.status = TradeStatus.Open;
        }

        // Check expritaion time
        assert_check_expiration(_trade_id);

        transfer_currency(
            saleTrade.owner, saleBid.bid_owner, saleBid.price, saleBid.currency_address
        );
        // transfer item to seller from bidder
        IERC721.transferFrom(
            saleTrade.token_contract, saleTrade.owner, saleBid.bid_owner, saleTrade.token_id
        );
          // Sale Trade Bid close function
        // TradeStatus.Cancelled if second parameter = 1
        // TradeStatus.Executed if second parameter = 2
        change_sale_bid_status(_trade_id, _bid_id, 2);

        // Sale Trade  close function
        // TradeStatus.Cancelled if second parameter = 1
        // TradeStatus.Executed if second parameter = 2
        change_sale_trade_status(_trade_id, 2);
        return ();
    }

    func cancel_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _trade_id: felt, _bid_id: felt
    ) {
        alloc_locals;

        let (caller) = get_caller_address();
        let (saleBid) = _bids.read(_trade_id, _bid_id);
        let (ownerOf) = IERC721.ownerOf(saleBid.bid_contract_address, saleBid.bid_token_id);

        with_attr error_message("Caller not owner of token") {
            assert ownerOf = caller;
        }

        with_attr error_message("Caller not owner of bid") {
            assert saleBid.bid_owner = caller;
        }

        with_attr error_message("Bid not open") {
            assert saleBid.status = TradeStatus.Open;
        }

        // Sale Trade Bid cancel function
        // TradeStatus.Cancelled if second parameter = 3
        // TradeStatus.Executed if second parameter = 2
        change_sale_bid_status(_trade_id, _bid_id, 3);

        return ();
    }

    //##########
    // GETTERS #
    //##########

    func trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_id: felt) -> (
        trade: SaleTrade
    ) {
        let (trade) = _trades.read(_id);
        return (trade);
    }

    func trade_counter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        trade_counter: felt
    ) {
        let (trade_counter) = _trade_counter.read();
        return (trade_counter);
    }

    // Returns a trades status
    func get_trade_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _id: felt
    ) -> (status: felt) {
        let (trade) = _trades.read(_id);
        return (trade.status);
    }

    // Returns a trades token
    func get_trade_token_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _id: felt
    ) -> (token_id: Uint256) {
        let (trade) = _trades.read(_id);
        return (trade.token_id);
    }


    // Returns a bid according to given trade_id and bid_id
    func bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _trade_id: felt, _bid_id: felt
    ) -> (trade: SaleBid) {
        let (bid) = _bids.read(_trade_id, _bid_id);
        return (bid);
    }

    // Returns bid count according to given trade_id 
    func get_bid_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _trade_id: felt
    ) -> (bid_count: felt) {
        let (bid_count) = _bid_to_item_counter.read(_trade_id);
        return (bid_count);
    }


    //##########
    // SETTERS #
    //##########

    func set_currency_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _erc20_address: felt
    ) -> (success: felt) {
        Ownable_only_owner();
        erc20_token_address.write(_erc20_address);
        return (1,);
    }

    func pause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        Ownable_only_owner();
        Pausable_pause();
        return ();
    }

    func unpause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        Ownable_only_owner();
        Pausable_unpause();
        return ();
    }
}

//##########
// HELPERS #
//##########

// If the bid owner cancels the bid or the bid is closed, the status changes
func change_sale_bid_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _trade_id: felt, _bid_id: felt, _status: felt
) {
    let (saleBid) = _bids.read(_trade_id, _bid_id);

    let _SaleBid = SaleBid(
        trade_id=_trade_id,
        bid_owner=saleBid.bid_owner,
        expiration=saleBid.expiration,
        currency_address=saleBid.currency_address,
        bid_price=saleBid.price,
        status=_status,
        bidded_nft_owner: saleBid.bidded_nft_owner,
        bidded_collection_address: saleBid.bidded_collection_address,
        bid_id = _bid_id,
        bid_type = saleBid.bid_type
    );

    _bids.write(_trade_id, _bid_id, _SaleBid);
    SaleBidAction.emit(_SaleBid);

    return ();
}

// If the trade owner cancels the listing or the trade is closed, the status changes
func change_sale_trade_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _trade_id: felt, _status: felt
) {
    let (saleTrade) = _trades.read(_trade_id);

    let _SaleTrade = SaleTrade(
        sale_trade_id=_trade_id,
        owner=saleTrade.owner,
        token_contract=saleTrade.token_contract,
        token_id=saleTrade.token_id,
        expiration=saleTrade.expiration,
        currency_address=saleTrade.currency_address,
        price=saleTrade.price,
        status=_status,
        trade_type=saleTrade.trade_type,
    );
    _trades.write(_trade_id, _SaleTrade);
    SaleAction.emit(_SaleTrade);

    return ();
}

func assert_check_expiration{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _id: felt
) {
    let (block_timestamp) = get_block_timestamp();
    let (trade) = _trades.read(_id);
    // check trade expiration within
    assert_nn_le(block_timestamp, trade.expiration);

    return ();
}

func transfer_currency{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _seller: felt, _buyer: felt, _price: Uint256, _currency_address: felt
) {
    alloc_locals;
   
    let (caller) = get_caller_address();
    let (balance: Uint256) = IERC20.balanceOf(_currency_address, _buyer);
    let (res) = uint256_le(_price, balance);
    with_attr error_message("insufficient balance") {
        assert res = 1;
    }
    // let (allowance : Uint256) =  IERC20.allowance(caller,contract_address)
    // assert_nn_le(sale_trade.price, balance)

    // eth transfer to seller
    IERC20.transferFrom(_currency_address, _buyer, _seller, _price);
    
    
    return ();
}

func uint_to_felt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value: Uint256
) -> (value: felt) {
    assert_lt_felt(value.high, 2 ** 123);
    return (value.high * (2 ** 128) + value.low,);
}