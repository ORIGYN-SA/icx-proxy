ADMIN_PRINCIPAL=$(dfx identity get-principal)
cd phone_book
dfx start --background --emulator 
dfx canister create phone_book 
dfx build phone_book 
dfx canister install phone_book --argument "(principal  \"$ADMIN_PRINCIPAL\")"
