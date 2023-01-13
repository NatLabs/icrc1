# ICRC1/Utils

## Function `init_metadata`
``` motoko no-repl
func init_metadata(args : T.InitArgs) : StableBuffer.StableBuffer<T.MetaDatum>
```


## Value `default_standard`
``` motoko no-repl
let default_standard : T.SupportedStandard
```


## Value `DAY_IN_NANO_SECONDS`
``` motoko no-repl
let DAY_IN_NANO_SECONDS : T.Timestamp
```


## Function `init_standards`
``` motoko no-repl
func init_standards() : StableBuffer.StableBuffer<T.SupportedStandard>
```


## Function `default_subaccount`
``` motoko no-repl
func default_subaccount() : T.Subaccount
```


## Function `hash`
``` motoko no-repl
func hash(n : Nat) : Hash.Hash
```


## Function `create_transfer_req`
``` motoko no-repl
func create_transfer_req(args : T.TransferArgs, owner : Principal, tx_kind : T.TxKind) : T.TransactionRequest
```


## Function `kind_to_text`
``` motoko no-repl
func kind_to_text(kind : T.TxKind) : Text
```


## Function `req_to_tx`
``` motoko no-repl
func req_to_tx(tx_req : T.TransactionRequest, index : Nat) : T.Transaction
```


## Function `div_ceil`
``` motoko no-repl
func div_ceil(n : Nat, d : Nat) : Nat
```


## Value `SB`
``` motoko no-repl
let SB
```

