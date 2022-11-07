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


## Function `args_to_req`
``` motoko no-repl
func args_to_req(operation : T.Operation, minting_account : T.Account) : T.TransactionRequest
```


## Function `kind_to_text`
``` motoko no-repl
func kind_to_text(kind : T.OperationKind) : Text
```


## Function `req_to_tx`
``` motoko no-repl
func req_to_tx(tx_req : T.TransactionRequest) : T.Transaction
```


## Value `SB`
``` motoko no-repl
let SB
```

