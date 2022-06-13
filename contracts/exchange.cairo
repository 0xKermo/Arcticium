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

############
# MAPPINGS #
############

namespace TradeStatus:
    const Open = 1
    const Executed = 2
    const Cancelled = 3
end

struct NftToNft:
    member token_contract : felt
    member token_id : Uint256
    member expiration : felt
    member price : felt # expect NFT + eth
    member status : felt  # from TradeStatus
    member trade_id : felt
    member target_token_contract : felt # nft contract address to be swapped
    member target_token_id : Uint256 # nft to be swapped
end


struct NftToAny:
    member token_contract : felt
    member token_id : Uint256
    member expiration : felt
    member price : felt # Nft + eth
    member status : felt  # from TradeStatus
    member trade_id : felt
end


struct NftToCollection:
    member token_contract : felt
    member token_id : Uint256
    member expiration : felt
    member price : felt # Nft + eth
    member status : felt  # from TradeStatus
    member trade_id : felt
    member target_collection_contract : felt
end




struct Bids:
    member bid_owner : felt
    member bid_nft : Uint256
    member expiration : felt
    member price : felt # Nft + eth
    member status : felt  # from TradeStatus
    member target_nft_owner : felt
    member target_nft_id : felt
    member bid_id : felt
end

###########
# STORAGE #
###########

# Indexed list of all trades
# @storage_var
# func _trades(idx : felt) -> (trade : Trade):
# end

# Indexed list of all bids
@storage_var
func _bids(idx : felt) -> (trade : Bids):
end

# Contract Address of ether used to purchase or sell items
@storage_var
func ether_token_address() -> (address : felt):
end

# The current number of trades
@storage_var
func trade_counter() -> (value : felt):
end



@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
     owner : felt
):
    Ownable_initializer(owner)
    return ()
end