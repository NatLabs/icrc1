# ICRC1/Types/Types.Transaction

## Type `BlockIndex`
``` motoko no-repl
type BlockIndex = Nat
```


## Type `Memo`
``` motoko no-repl
type Memo = Blob
```


## Type `Timestamp`
``` motoko no-repl
type Timestamp = Nat64
```


## Type `Duration`
``` motoko no-repl
type Duration = Nat64
```


## Type `TxIndex`
``` motoko no-repl
type TxIndex = Nat
```


## Type `TxCandidBlob`
``` motoko no-repl
type TxCandidBlob = Blob
```


## Type `TimeError`
``` motoko no-repl
type TimeError = {#TooOld; #CreatedInFuture : { ledger_time : Timestamp }}
```


## Type `TxKind`
``` motoko no-repl
type TxKind = {#mint; #burn; #transfer}
```


## Type `TransferResult`
``` motoko no-repl
type TransferResult = {#Ok : TxIndex; #Err : TransferError}
```


## Type `TransferError`
``` motoko no-repl
type TransferError = TimeError or {#BadFee : { expected_fee : Balance }; #BadBurn : { min_burn_amount : Balance }; #InsufficientFunds : { balance : Balance }; #Duplicate : { duplicate_of : TxIndex }; #TemporarilyUnavailable; #GenericError : { error_code : Nat; message : Text }}
```


## Type `Mint`
``` motoko no-repl
type Mint = { to : Account; amount : Balance; memo : ?Blob; created_at_time : ?Nat64 }
```


## Type `BurnArgs`
``` motoko no-repl
type BurnArgs = { from_subaccount : ?Subaccount; amount : Balance; memo : ?Blob; created_at_time : ?Nat64 }
```


## Type `Burn`
``` motoko no-repl
type Burn = { from : Account; amount : Balance; memo : ?Blob; created_at_time : ?Nat64 }
```


## Type `TransferArgs`
``` motoko no-repl
type TransferArgs = { from_subaccount : ?Subaccount; to : Account; amount : Balance; fee : ?Balance; memo : ?Blob; created_at_time : ?Nat64 }
```

Arguments for a transfer operation

## Type `Transfer`
``` motoko no-repl
type Transfer = { from : Account; to : Account; amount : Balance; fee : ?Balance; memo : ?Blob; created_at_time : ?Nat64 }
```


## Type `TransactionRequest`
``` motoko no-repl
type TransactionRequest = { kind : TxKind; from : Account; to : Account; amount : Balance; fee : ?Balance; memo : ?Blob; created_at_time : ?Nat64; encoded : { from : EncodedAccount; to : EncodedAccount } }
```

Internal representation of a transaction request

## Type `Transaction`
``` motoko no-repl
type Transaction = { kind : Text; mint : ?Mint; burn : ?Burn; transfer : ?Transfer; index : TxIndex; timestamp : Timestamp }
```


## Type `GetTransactionsRequest`
``` motoko no-repl
type GetTransactionsRequest = { start : TxIndex; length : Nat }
```

The type to request a range of transactions from the ledger canister

## Type `TransactionRange`
``` motoko no-repl
type TransactionRange = { transactions : [Transaction] }
```


## Type `QueryArchiveFn`
``` motoko no-repl
type QueryArchiveFn = shared query (GetTransactionsRequest) -> async TransactionRange
```


## Type `ArchivedTransaction`
``` motoko no-repl
type ArchivedTransaction = { start : TxIndex; length : Nat; callback : QueryArchiveFn }
```


## Type `GetTransactionsResponse`
``` motoko no-repl
type GetTransactionsResponse = { log_length : Nat; first_index : TxIndex; transactions : [Transaction]; archived_transactions : [ArchivedTransaction] }
```

