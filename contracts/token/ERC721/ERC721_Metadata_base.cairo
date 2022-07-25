%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

from contracts.token.ERC721.ERC721_base import (
    _exists
)

from contracts.token.ERC165_base import (
    ERC165_register_interface
)

from contracts.token.lib.ShortString import uint256_to_ss
from contracts.token.lib.Array import concat_arr

#
# Storage
#

@storage_var
func ERC721_base_token_uri(token_id: Uint256, index: felt) -> (res: felt):
end

@storage_var
func ERC721_base_token_uri_len(token_id: Uint256) -> (res: felt):
end


#
# Constructor
#

func ERC721_Metadata_initializer{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # register IERC721_Metadata
    ERC165_register_interface(0x5b5e139f)
    return ()
end

func ERC721_Metadata_tokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256) -> (token_uri_len: felt, token_uri: felt*):
    alloc_locals

    let (exists) = _exists(token_id)
    assert exists = 1

    let (local base_token_uri) = alloc()
    let (local base_token_uri_len) = ERC721_base_token_uri_len.read(token_id)

    _ERC721_Metadata_baseTokenURI(token_id,base_token_uri_len, base_token_uri)

    let (token_id_ss_len, token_id_ss) = uint256_to_ss(token_id)
    let (token_uri, token_uri_len) = concat_arr(
        base_token_uri_len,
        base_token_uri,
        token_id_ss_len,
        token_id_ss,
    )

    return (token_uri_len=token_uri_len, token_uri=token_uri)
end

func _ERC721_Metadata_baseTokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256,base_token_uri_len: felt, base_token_uri: felt*):
    if base_token_uri_len == 0:
        return ()
    end
    let (base) = ERC721_base_token_uri.read(token_id,base_token_uri_len)
    assert [base_token_uri] = base
    _ERC721_Metadata_baseTokenURI(token_id,base_token_uri_len=base_token_uri_len - 1, base_token_uri=base_token_uri + 1)
    return ()
end

func ERC721_Metadata_setBaseTokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256,token_uri_len: felt, token_uri: felt*):
    _ERC721_Metadata_setBaseTokenURI(token_id,token_uri_len, token_uri)
    ERC721_base_token_uri_len.write(token_id,token_uri_len)
    return ()
end

func _ERC721_Metadata_setBaseTokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256,token_uri_len: felt, token_uri: felt*):
    if token_uri_len == 0:
        return ()
    end
    ERC721_base_token_uri.write(token_id=token_id,index=token_uri_len, value=[token_uri])
    _ERC721_Metadata_setBaseTokenURI(token_id,token_uri_len=token_uri_len - 1, token_uri=token_uri + 1)
    return ()
end
