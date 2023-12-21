# ICRC1/Types/Types.Canister

## Type `CanisterStatsResponse`
``` motoko no-repl
type CanisterStatsResponse = { name : Text; principal : Text; balance : CommonTypes.Balance }
```


## Type `CanisterAutoTopUpData`
``` motoko no-repl
type CanisterAutoTopUpData = { var autoCyclesTopUpEnabled : Bool; var autoCyclesTopUpMinutes : Nat; var autoCyclesTopUpTimerId : Nat; var autoCyclesTopUpOccuredNumberOfTimes : Nat }
```


## Type `CanisterAutoTopUpDataResponse`
``` motoko no-repl
type CanisterAutoTopUpDataResponse = { autoCyclesTopUpEnabled : Bool; autoCyclesTopUpMinutes : Nat; autoCyclesTopUpTimerId : Nat; autoCyclesTopUpOccuredNumberOfTimes : Nat }
```

