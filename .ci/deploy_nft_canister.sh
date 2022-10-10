#!/bin/bash
ADMIN_PRINCIPAL=$(dfx identity get-principal)
cd origyn_nft
dfx start --background --emulator 
dfx canister create origyn_nft_reference
dfx build origyn_nft_reference 
dfx canister install origyn_nft_reference --argument "(record {owner = principal \"$ADMIN_PRINCIPAL\"; storage_space = null})" &&\
cd ..