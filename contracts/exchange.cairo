// SPDX-License-Identifier: MIT
// Arciticum exchange 

%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_eq
from starkware.cairo.common.bool import TRUE, FALSE

from contracts.openzeppelin.access.ownable.library import Ownable
from contracts.openzeppelin.security.pausable.library import Pausable

from contracts.utils.structs import SwapTrade, SwapBid
from contracts.exchanges.swap import Swap_Trade

//##########
// STORAGE #
//##########

// Contract Address of ether used to purchase or sell items
@storage_var
func erc20_token_addresses(idx: felt) -> (address: felt) {
}

// Contract Address of ether used to purchase or sell items
@storage_var
func erc20_token_count() -> (count: felt) {
}

@storage_var
func is_initialize() -> (initialized: felt) {
}

//##############
// CONSTRUCTOR #
//##############

@external
func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
    let (initialized) = is_initialize.read();
    with_attr error_message("contract already initialized") {
        assert initialized = FALSE;
    }
    is_initialize.write(TRUE);
    Ownable.initializer(owner);
    return ();
}

//#############
// SWAP TRADE #
//#############

@external
func open_swap_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token_contract: felt,
    _token_id: Uint256,
    _expiration: felt,
    _currency_id: felt,
    _price: Uint256,
    _trade_type: felt,
    _target_token_contract: felt,
    _target_token_id: Uint256,
) {
    alloc_locals;
    Pausable.assert_not_paused();
    let (currency_address) = erc20_token_addresses.read(_currency_id);

    if (currency_address == 0) {
        let (res) = uint256_eq(_price, Uint256(0, 0));
        with_attr error_message("assert_uint256_eq failed") {
            assert res = 1;
        }
    }
    Swap_Trade.list_item(
        _token_contract,
        _token_id,
        _expiration,
        currency_address,
        _price,
        _trade_type,
        _target_token_contract,
        _target_token_id,
    );

    return ();
}

@external
func execute_swap_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _id: felt
) {
    alloc_locals;
    Pausable.assert_not_paused();

    Swap_Trade.swap_item(_id);

    return ();
}

@external
func update_swap_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _id: felt, price: Uint256, _target_token_contract: felt, _target_token_id: Uint256
) {
    alloc_locals;
    Pausable.assert_not_paused();
    Swap_Trade.update_listing(_id, price, _target_token_contract, _target_token_id);

    return ();
}

@external
func cancel_swap_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_id: felt) {
    alloc_locals;
    Pausable.assert_not_paused();

    Swap_Trade.cancel_trade(_id);

    return ();
}

//#############
// SWAP BİD #
//#############

@external
func open_swap_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _swap_trade_id: felt,
    _bid_contract_address: felt,
    _bid_token_id: Uint256,
    _expiration: felt,
    _currency_id: felt,
    _price: Uint256,
    _target_token_contract: felt,
    _target_token_id: Uint256,
) {
    alloc_locals;
    Pausable.assert_not_paused();
    let (currency_address) = erc20_token_addresses.read(_currency_id);
    if (currency_address == 0) {
        let (res) = uint256_eq(_price, Uint256(0, 0));
        with_attr error_message("assert_uint256_eq failed") {
            assert res = 1;
        }
    }
    Swap_Trade.bid_to_item(
        _swap_trade_id,
        _bid_contract_address,
        _bid_token_id,
        _expiration,
        currency_address,
        _price,
        _target_token_contract,
        _target_token_id,
    );

    return ();
}

@external
func cancel_swap_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _trade_id: felt, _bid_id: felt
) {
    alloc_locals;
    Pausable.assert_not_paused();
    Swap_Trade.cancel_bid(_trade_id, _bid_id);
    return ();
}

@external
func accept_swap_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _trade_id: felt, _bid_id: felt
) {
    alloc_locals;
    Pausable.assert_not_paused();
    Swap_Trade.accept_bid(_trade_id, _bid_id);
    return ();
}

//######################
//       GETTERS      #
//#####################

//#############
// SWAP GET.  #
//#############

@view
func get_swap_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_id: felt) -> (
    trade: SwapTrade
) {
    let (trade: SwapTrade) = Swap_Trade.trade(_id);
    return (trade,);
}

@view
func get_swap_trade_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    trade_counter: felt
) {
    let (trade_counter) = Swap_Trade.trade_counter();
    return (trade_counter,);
}

@view
func get_swap_item_bid_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _trade_id: felt
) -> (bid_count: felt) {
    let (bid_count) = Swap_Trade.get_bid_count(_trade_id);
    return (bid_count,);
}

@view
func get_swap_item_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _trade_id: felt, _bid_id: felt
) -> (bid: SwapBid) {
    let (bid) = Swap_Trade.bid(_trade_id, _bid_id);
    return (bid,);
}

@view
func get_swap_item_bids{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _trade_id: felt
) -> (bids_len: felt, bids: SwapBid*) {
    let (bids_len, bids) = Swap_Trade.get_all_bids(_trade_id);
    return (bids_len, bids);
}

@view
func get_currency_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _id: felt
) -> (currency_address: felt) {
    let (currency_address) = erc20_token_addresses.read(_id);
    return (currency_address,);
}

@view
func get_erc20_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    erc20_count: felt
) {
    let (erc20_count) = erc20_token_count.read();
    return (erc20_count,);
}

//#############
//   COMMON   #
//#############

@view
func paused{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (paused: felt) {
    let (paused) = Pausable.is_paused();
    return (paused,);
}

@external
func add_currency_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _erc20_address: felt
) -> (success: felt) {
    alloc_locals;
    Ownable.assert_only_owner();
    let (erc20_count) = erc20_token_count.read();
    erc20_token_addresses.write(erc20_count + 1, _erc20_address);
    erc20_token_count.write(erc20_count + 1);
    return (1,);
}

@external
func pauseTrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.assert_only_owner();
    Pausable._pause();
    return ();
}

@external
func unpauseTrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.assert_only_owner();
    Pausable._unpause();
    return ();
}