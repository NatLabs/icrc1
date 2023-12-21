# ICRC1/Types/Types.Token

## Type `MetaDatum`
``` motoko no-repl
type MetaDatum = (Text, Value)
```


## Type `MetaData`
``` motoko no-repl
type MetaData = [MetaDatum]
```


## Type `InitArgs`
``` motoko no-repl
type InitArgs = { name : Text; symbol : Text; decimals : Nat8; fee : Balance; logo : Text; minting_account : Account; max_supply : Balance; initial_balances : [(Account, Balance)]; min_burn_amount : Balance; minting_allowed : Bool }
```

Initial arguments for the setting up the icrc1 token canister

## Type `TokenInitArgs`
``` motoko no-repl
type TokenInitArgs = { name : Text; symbol : Text; decimals : Nat8; fee : Balance; logo : Text; max_supply : Balance; initial_balances : [(Account, Balance)]; min_burn_amount : Balance; minting_account : ?Account; minting_allowed : Bool }
```

[InitArgs](#type.InitArgs) with optional fields for initializing a token canister

## Type `TokenData`
``` motoko no-repl
type TokenData = { var name : Text; var symbol : Text; var decimals : Nat8; var fee : Balance; var logo : Text; max_supply : Balance; var minted_tokens : Balance; minting_allowed : Bool; var burned_tokens : Balance; var minting_account : Account; accounts : AccountBalances; metadata : StableBuffer<MetaDatum>; supported_standards : StableBuffer<SupportedStandard>; transaction_window : Nat; var min_burn_amount : Balance; permitted_drift : Nat; transactions : StableBuffer<Transaction>; archive : ArchiveData }
```

The state of the token canister

## Type `SupportedStandard`
``` motoko no-repl
type SupportedStandard = { name : Text; url : Text }
```


## Type `SetParameterError`
``` motoko no-repl
type SetParameterError = {#GenericError : { error_code : Nat; message : Text }}
```


## Type `SetTextParameterResult`
``` motoko no-repl
type SetTextParameterResult = {#Ok : Text; #Err : SetParameterError}
```


## Type `SetNat8ParameterResult`
``` motoko no-repl
type SetNat8ParameterResult = {#Ok : Nat8; #Err : SetParameterError}
```


## Type `SetBalanceParameterResult`
``` motoko no-repl
type SetBalanceParameterResult = {#Ok : Balance; #Err : SetParameterError}
```


## Type `SetAccountParameterResult`
``` motoko no-repl
type SetAccountParameterResult = {#Ok : Account; #Err : SetParameterError}
```


## Type `TokenInterface`
``` motoko no-repl
type TokenInterface = actor { icrc1_name : shared query () -> async Text; icrc1_symbol : shared query () -> async Text; icrc1_decimals : shared query () -> async Nat8; icrc1_fee : shared query () -> async Balance; icrc1_metadata : shared query () -> async MetaData; icrc1_total_supply : shared query () -> async Balance; icrc1_minting_account : shared query () -> async ?Account; icrc1_balance_of : shared query (Account) -> async Balance; icrc1_transfer : shared (TransferArgs) -> async TransferResult; icrc1_supported_standards : shared query () -> async [SupportedStandard] }
```

Interface for the ICRC token canister

## Type `RosettaInterface`
``` motoko no-repl
type RosettaInterface = actor { get_transactions : shared query (GetTransactionsRequest) -> async GetTransactionsResponse }
```

Functions supported by the rosetta 

## Type `FullInterface`
``` motoko no-repl
type FullInterface = TokenInterface and RosettaInterface
```

Interface of the ICRC token and Rosetta canister
