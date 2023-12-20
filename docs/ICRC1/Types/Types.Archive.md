# ICRC1/Types/Types.Archive

## Type `ArchiveCanisterIds`
``` motoko no-repl
type ArchiveCanisterIds = { var canisterIds : List.List<Principal> }
```


## Type `ArchiveInterface`
``` motoko no-repl
type ArchiveInterface = actor { init : shared () -> async Principal; append_transactions : shared ([Transaction]) -> async Result.Result<(), Text>; total_transactions : shared query () -> async Nat; get_transaction : shared query (TxIndex) -> async ?Transaction; get_transactions : shared query (GetTransactionsRequest) -> async TransactionRange; remaining_capacity : shared query () -> async Nat; total_used : shared query () -> async Nat; max_memory : shared query () -> async Nat; get_first_tx : shared query () -> async Nat; get_last_tx : shared query () -> async Nat; get_prev_archive : shared query () -> async ArchiveInterface; get_next_archive : shared query () -> async ArchiveInterface; set_first_tx : shared (Nat) -> async Result.Result<(), Text>; set_last_tx : shared (Nat) -> async Result.Result<(), Text>; set_prev_archive : shared (ArchiveInterface) -> async Result.Result<(), Text>; set_next_archive : shared (ArchiveInterface) -> async Result.Result<(), Text>; cycles_available : shared query () -> async Nat; deposit_cycles : shared () -> async () }
```

The Interface for the Archive canister

## Type `ArchiveData`
``` motoko no-repl
type ArchiveData = { var canister : ArchiveInterface; var stored_txs : Nat }
```

The details of the archive canister
