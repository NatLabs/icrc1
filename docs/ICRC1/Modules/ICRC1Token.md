# ICRC1/Modules/ICRC1Token

## Function `init`
``` motoko no-repl
func init(args : T.TokenTypes.InitArgs) : T.TokenTypes.TokenData
```

Initialize a new ICRC-1 token

## Function `name`
``` motoko no-repl
func name(token : TokenData) : Text
```

Retrieve the name of the token

## Function `symbol`
``` motoko no-repl
func symbol(token : TokenData) : Text
```

Retrieve the symbol of the token

## Function `decimals`
``` motoko no-repl
func decimals(token : TokenData) : Nat8
```

Retrieve the number of decimals specified for the token

## Function `fee`
``` motoko no-repl
func fee(token : TokenData) : Balance
```

Retrieve the fee for each transfer

## Function `min_burn_amount`
``` motoko no-repl
func min_burn_amount(token : TokenData) : Balance
```

Retrieve the minimum burn amount for the token

## Function `set_name`
``` motoko no-repl
func set_name(token : TokenData, name : Text, caller : Principal) : async* SetTextParameterResult
```

Set the name of the token

## Function `set_symbol`
``` motoko no-repl
func set_symbol(token : TokenData, symbol : Text, caller : Principal) : async* SetTextParameterResult
```

Set the symbol of the token

## Function `set_logo`
``` motoko no-repl
func set_logo(token : TokenData, logo : Text, caller : Principal) : async* SetTextParameterResult
```

Set the logo for the token

## Function `set_fee`
``` motoko no-repl
func set_fee(token : TokenData, fee : Nat, caller : Principal) : async* SetBalanceParameterResult
```

Set the fee for each transfer

## Function `set_decimals`
``` motoko no-repl
func set_decimals(token : TokenData, decimals : Nat8, caller : Principal) : async* SetNat8ParameterResult
```

Set the number of decimals specified for the token

## Function `set_min_burn_amount`
``` motoko no-repl
func set_min_burn_amount(token : TokenData, min_burn_amount : Nat, caller : Principal) : async* SetBalanceParameterResult
```

Set the minimum burn amount

## Function `metadata`
``` motoko no-repl
func metadata(token : TokenData) : [MetaDatum]
```

Retrieve all the metadata of the token

## Function `get_archive`
``` motoko no-repl
func get_archive(token : TokenData) : ArchiveInterface
```

Returns the current archive canister

## Function `get_archive_stored_txs`
``` motoko no-repl
func get_archive_stored_txs(token : TokenData) : Nat
```

Returns the total number of transactions in the archive

## Function `total_supply`
``` motoko no-repl
func total_supply(token : TokenData) : Balance
```

Returns the total supply of circulating tokens

## Function `minted_supply`
``` motoko no-repl
func minted_supply(token : TokenData) : Balance
```

Returns the total supply of minted tokens

## Function `burned_supply`
``` motoko no-repl
func burned_supply(token : TokenData) : Balance
```

Returns the total supply of burned tokens

## Function `max_supply`
``` motoko no-repl
func max_supply(token : TokenData) : Balance
```

Returns the maximum supply of tokens

## Function `minting_account`
``` motoko no-repl
func minting_account(token : TokenData) : Account
```

Returns the account with the permission to mint tokens

Note: **The minting account can only participate in minting
and burning transactions, so any tokens sent to it will be
considered burned.**

## Function `balance_of`
``` motoko no-repl
func balance_of(account : Account) : Balance
```

Retrieve the balance of a given account

## Function `supported_standards`
``` motoko no-repl
func supported_standards(token : TokenData) : [SupportedStandard]
```

Returns an array of standards supported by this token

## Function `balance_from_float`
``` motoko no-repl
func balance_from_float(token : TokenData, float : Float) : Balance
```

Formats a float to a nat balance and applies the correct number of decimal places

## Function `transfer`
``` motoko no-repl
func transfer(token : TokenData, args : TransferArgs, caller : Principal, archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds) : async* TransferResult
```

Transfers tokens from one account to another account (minting and burning included)    

## Function `mint`
``` motoko no-repl
func mint(token : TokenData, args : Mint, caller : Principal, archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds) : async* TransferResult
```

Helper function to mint tokens with minimum args

## Function `burn`
``` motoko no-repl
func burn(token : TokenData, args : BurnArgs, caller : Principal, archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds) : async* TransferResult
```

Helper function to burn tokens with minimum args

## Function `total_transactions`
``` motoko no-repl
func total_transactions(token : TokenData) : Nat
```

Returns the total number of transactions that have been processed by the given token.

## Function `get_transaction`
``` motoko no-repl
func get_transaction(token : TokenData, tx_index : TxIndex) : async* ?Transaction
```

Retrieves the transaction specified by the given `tx_index`

## Function `get_transactions`
``` motoko no-repl
func get_transactions(token : TokenData, req : GetTransactionsRequest) : GetTransactionsResponse
```

Retrieves the transactions specified by the given range

## Function `get_holders`
``` motoko no-repl
func get_holders(token : TokenData, index : ?Nat, count : ?Nat) : [T.AccountTypes.AccountBalanceInfo]
```

Returns the list of the token-holders - with their balances included

## Function `all_canister_stats`
``` motoko no-repl
func all_canister_stats(hidePrincipal : Bool, mainTokenPrincipal : Principal, mainTokenBalance : Balance, archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds) : async* [T.CanisterTypes.CanisterStatsResponse]
```

Get the canister's cycle balance information for all the created archive canisters.
If this method was called from minting-owner account then also the canister-id's are included.
