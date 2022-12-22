# ICRC1/Account

## Function `validate_subaccount`
``` motoko no-repl
func validate_subaccount(subaccount : ?T.Subaccount) : Bool
```

Checks if a subaccount is valid

## Function `validate`
``` motoko no-repl
func validate(account : T.Account) : Bool
```

Checks if an account is valid

## Function `encode`
``` motoko no-repl
func encode() : T.EncodedAccount
```

Implementation of ICRC1's Textual representation of accounts [Encoding Standard](https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-1#encoding)

## Function `decode`
``` motoko no-repl
func decode(encoded : T.EncodedAccount) : ?T.Account
```

Implementation of ICRC1's Textual representation of accounts [Decoding Standard](https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-1#decoding)

## Function `get_balance`
``` motoko no-repl
func get_balance(accounts : T.AccountBalances, encoded_account : T.EncodedAccount) : T.Balance
```

Retrieves the balance of an account

## Function `update_balance`
``` motoko no-repl
func update_balance(accounts : T.AccountBalances, encoded_account : T.EncodedAccount, update : (T.Balance) -> T.Balance)
```

Updates the balance of an account

## Function `transfer_balance`
``` motoko no-repl
func transfer_balance(accounts : T.AccountBalances, tx_req : T.TransactionRequest)
```

Transfers tokens from the sender to the
recipient in the tx request
