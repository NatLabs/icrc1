import Result "mo:base/Result";

module{
    public type SubAccount = Blob;

    public type Account = { 
        owner : Principal; 
        subaccount : ?ubAccount;
    };

    /// Interface for the ICRC token canister
    public type TokenInterface = actor {

        /// Returns the name of the token
        icrc1_name : query () -> async Text;

        /// Returns the symbol of the token
        icrc1_symbol : query () -> async Text;
        
        icrc1_decimaal : query () -> async Nat8;

        icrc1_fee : query () -> async Nat;

        icrc1_metadata : query () -> async ( Text, Value );

        icrc1_total_supply : query () -> async Nat;

        icrc1_minting_account : query () -> async ?Account;

        icrc1_balance_of : query (Account) -> async Nat;

        icrc1_transfer : query (TransferArgs) -> async Result.Result<Nat, TransferError>;

        icrc1_supported_standards : () -> [K]
    };

    public type Account = { owner : Principal; subaccount : ?SubAccount; };
    public type SubAccount = Blob;
    public type Tokens = Nat;
    public type Memo = Blob;
    public type Timestamp = Nat64;
    public type Duration = Nat64;
    public type TxIndex = Nat;
    public type TxLog = Buffer.Buffer<Transaction>;

    public type Value = { #Nat : Nat; #Int : Int; #Blob : Blob; #Text : Text; };

    public type TransferArgs = {
        from_subaccount : ?SubAccount;
        to : Account;
        amount : Nat;
        fee : ?Nat;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type TransferError = {
        #BadFee : { expected_fee : Tokens };
        #BadBurn : { min_burn_amount : Tokens };
        #InsufficientFunds : { balance : Tokens };
        #TooOld;
        #CreatedInFuture : { ledger_time: Timestamp };
        #Duplicate : { duplicate_of : TxIndex };
        #TemporarilyUnavailable;
        #GenericError : { error_code : Nat; message : Text };
    };

    
}