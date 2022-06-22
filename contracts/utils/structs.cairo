%lang starknet
from starkware.cairo.common.uint256 import Uint256

struct SaleTrade:
    member owner :felt
    member token_contract : felt
    member token_id : Uint256
    member expiration : felt
    member price : felt # eth
    member status : felt  # from TradeStatus
    member sale_trade_id : felt
end

struct SwapTrade:
    member owner :felt
    member token_contract : felt
    member token_id : Uint256
    member expiration : felt
    member price : felt # expect NFT + eth
    member status : felt  # from TradeStatus
    member swap_trade_id : felt
    member target_token_contract : felt # nft contract address to be swapped
    member target_token_id : Uint256 # nft to be swapped
end

struct SaleBid:
    member bid_owner : felt
    member expiration : felt
    member bid_price : felt # eth
    member status : felt  # from TradeStatus
    member bidden_nft_owner : felt
    member bidden_collection_address : felt
    member target_nft_id : felt
    member bid_id : felt
end

struct SwapBid:
    member bid_owner : felt
    member bid_collection_address : felt 
    member bid_nft_id : Uint256
    member expiration : felt
    member price : felt # Nft + eth
    member status : felt  # from TradeStatus
    member target_nft_owner : felt
    member target_collection_address : felt
    member target_nft_id : felt
    member bid_id : felt
end

