# ICRC1/Modules/Transfer

## Function `validate_request`
``` motoko no-repl
func validate_request(token : TokenData, tx_req : TransactionRequest) : Result.Result<(), TransferError>
```

Checks if a transfer request is valid
