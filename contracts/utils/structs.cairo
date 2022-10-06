%lang starknet

from starkware.cairo.common.uint256 import Uint256

struct SaleTrade {
    sale_trade_id: felt,
    owner: felt,
    token_contract: felt,
    token_id: Uint256,
    expiration: felt,
    currency_address: felt,
    price: felt,  // eth
    status: felt,  // from TradeStatus
    trade_type: felt,
}

struct SwapTrade {
    swap_trade_id: felt,
    owner: felt,
    token_contract: felt,
    token_id: Uint256,
    expiration: felt,
    currency_address: felt,
    price: Uint256,  // expect NFT + eth
    status: felt,  // from TradeStatus
    trade_type: felt,
    target_token_contract: felt,  // nft contract address to be swapped
    target_token_id: Uint256,  // nft to be swapped
}

struct SaleBid {
    trade_id: felt,
    bid_owner: felt,
    expiration: felt,
    currency_address: felt,
    bid_price: felt,  // eth
    status: felt,  // from TradeStatus
    bidded_nft_owner: felt,
    bidded_collection_address: felt,
    bid_id: felt,
    bid_type:felt
}

struct SwapBid {
    trade_id: felt,
    bid_owner: felt,
    bid_contract_address: felt,
    bid_token_id: Uint256,
    expiration: felt,
    currency_address: felt,
    price: Uint256,  // Nft + eth
    status: felt,  // from TradeStatus
    target_nft_owner: felt,
    target_token_contract: felt,
    target_token_id: Uint256,
    item_bid_id: felt,
}