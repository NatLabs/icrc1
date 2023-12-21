# ICRC1/Modules/Account

## Function `encode`
``` motoko no-repl
func encode() : EncodedAccount
```

Implementation of ICRC1's Textual representation of accounts [Encoding Standard](https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-1#encoding)

## Function `decode`
``` motoko no-repl
func decode(encoded : EncodedAccount) : ?Account
```

Implementation of ICRC1's Textual representation of accounts [Decoding Standard](https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-1#decoding)

## Function `validate_subaccount`
``` motoko no-repl
func validate_subaccount(subaccount : ?Subaccount) : Bool
```

Checks if a subaccount is valid

## Function `validate`
``` motoko no-repl
func validate(account : Account) : Bool
```

Checks if an account is valid

## Function `fromText`
``` motoko no-repl
func fromText(text : Text) : Result.Result<Account, ParseError>
```

Converts an ICRC-1 Account from its Textual representation to the `Account` type
Parses account from its textual representation.

## Function `toText`
``` motoko no-repl
func toText(account : Account) : Text
```

Converts an ICRC-1 `Account` to its Textual representation

## Function `checkSum`
``` motoko no-repl
func checkSum(owner : Principal, subaccount : Blob) : Text
```

