# ICRC1/Modules/Utils

## Function `init_metadata`
``` motoko no-repl
func init_metadata(args : InitArgs) : StableBuffer.StableBuffer<MetaDatum>
```

Creates a Stable Buffer with the default metadata and returns it.

## Value `default_standard`
``` motoko no-repl
let default_standard : SupportedStandard
```


## Function `init_standards`
``` motoko no-repl
func init_standards() : StableBuffer.StableBuffer<SupportedStandard>
```

Creates a Stable Buffer with the default supported standards and returns it.

## Function `default_subaccount`
``` motoko no-repl
func default_subaccount() : Subaccount
```

Returns the default subaccount for cases where a user does
not specify it.

## Function `hash`
``` motoko no-repl
func hash(n : Nat) : Hash.Hash
```

Computes a hash from the least significant 32-bits of `n`, ignoring other bits.

## Function `create_transfer_req`
``` motoko no-repl
func create_transfer_req(args : TransferArgs, owner : Principal, tx_kind : TxKind) : TransactionRequest
```

Formats the different operation arguments into
a `TransactionRequest`, an internal type to access fields easier.

## Function `kind_to_text`
``` motoko no-repl
func kind_to_text(kind : TxKind) : Text
```

Transforms the transaction kind from `variant` to `Text`

## Function `req_to_tx`
``` motoko no-repl
func req_to_tx(tx_req : TransactionRequest, index : Nat) : Transaction
```

Formats the tx request into a finalised transaction

## Function `div_ceil`
``` motoko no-repl
func div_ceil(n : Nat, d : Nat) : Nat
```


## Function `get_balance`
``` motoko no-repl
func get_balance(accounts : AccountBalances, encoded_account : EncodedAccount) : Balance
```

Retrieves the balance of an account

## Function `transfer_balance`
``` motoko no-repl
func transfer_balance(token : TokenData, tx_req : TransactionRequest)
```

Transfers tokens from the sender to the
recipient in the tx request

## Function `mint_balance`
``` motoko no-repl
func mint_balance(token : TokenData, encoded_account : EncodedAccount, amount : Balance)
```

Function to mint tokens

## Function `burn_balance`
``` motoko no-repl
func burn_balance(token : TokenData, encoded_account : EncodedAccount, amount : Balance)
```

Function to burn tokens

## Value `SB`
``` motoko no-repl
let SB
```

Stable Buffer Module with some additional functions
