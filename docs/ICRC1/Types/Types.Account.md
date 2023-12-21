# ICRC1/Types/Types.Account

## Type `EncodedAccount`
``` motoko no-repl
type EncodedAccount = Blob
```


## Type `Subaccount`
``` motoko no-repl
type Subaccount = Blob
```


## Type `AccountBalances`
``` motoko no-repl
type AccountBalances = STMap.StableTrieMap<EncodedAccount, CommonTypes.Balance>
```


## Type `ParseError`
``` motoko no-repl
type ParseError = {#malformed : Text; #not_canonical; #bad_checksum}
```


## Type `Account`
``` motoko no-repl
type Account = { owner : Principal; subaccount : ?Subaccount }
```


## Type `AccountBalanceInfo`
``` motoko no-repl
type AccountBalanceInfo = { account : Account; balance : CommonTypes.Balance }
```

