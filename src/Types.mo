import Result "mo:base/Result";

import StableBuffer "mo:StableBuffer/StableBuffer";
import STMap "mo:StableTrieMap";

module{

    public type Subaccount = Blob;
    public type Balance = Nat;
    public type StableBuffer<T> = StableBuffer.StableBuffer<T>;
    public type StableTrieMap<K, V> = STMap.StableTrieMap<K, V>;

    public type Account = { 
        owner : Principal; 
        subaccount : ?Subaccount;
    };

    public type SupportedStandard = {
        name : Text;
        url : Text;
    };

    public type Memo = Blob;
    public type Timestamp = Nat64;
    public type Duration = Nat64;
    public type TxIndex = Nat;
    public type TxLog = StableBuffer<Transaction>;

    public type Value = { 
        #Nat : Nat; 
        #Int : Int; 
        #Blob : Blob; 
        #Text : Text; 
    };

    public type MetaDatum = (Text, Value);

    public type TxType = {
        #mint;
        #burn;
        #transfer;
    };

    public type Transaction = {
        txtype: TxType;
        from : Account;
        to : Account;
        amount : Balance;
        memo : Memo;
        fee : Balance;
        time : Timestamp;
    };

    public type MintArgs = {
        to : Account;
        amount : Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type BurnArgs = {
        from_subaccount : ?Subaccount;
        amount : Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type TransferArgs = {
        from_subaccount : ?Subaccount;
        to : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type InternalTransferArgs = {
        sender : Account;
        recipient : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type TimeError = {
        #TooOld;
        #CreatedInFuture : { ledger_time: Timestamp };
    };

    public type TransferError = TimeError or {
        #BadFee : { expected_fee : Balance };
        #BadBurn : { min_burn_amount : Balance };
        #InsufficientFunds : { balance : Balance };
        #Duplicate : { duplicate_of : TxIndex };
        #TemporarilyUnavailable;
        #GenericError : { error_code : Nat; message : Text };
    };

    /// Interface for the ICRC token canister
    public type Interface = actor {

        /// Returns the name of the token
        icrc1_name : query () -> async Text;

        /// Returns the symbol of the token
        icrc1_symbol : query () -> async Text;
        
        icrc1_decimals : query () -> async Nat8;

        icrc1_fee : query () -> async Balance;

        icrc1_metadata : query () -> async [MetaDatum];

        icrc1_total_supply : query () -> async Balance;

        icrc1_minting_account : query () -> async ?Account;

        icrc1_balance_of : query (Account) -> async Balance;

        icrc1_transfer : (TransferArgs) -> async Result.Result<Balance, TransferError>;

        icrc1_supported_standards : query () -> async [SupportedStandard]
    };

    public type InitArgs = {
        name: Text;
        symbol: Text;
        decimals : Nat8;
        fee: Balance;
        minting_account : Account;
        max_supply : Balance;
        store_transactions: Bool;
    };

    public type ExportedArgs = InitArgs and {
        /// Time between when a transaction is created on the frontend
        /// and sent to the canister for execution.
        /// **This value should be in seconds**
        transaction_window : ?Timestamp;

        // The minting_account defaults to account of the  
        // canister if its null
        minting_account: ?Account;
        metadata : ?[MetaDatum];
        supported_standards : ?[SupportedStandard];

        // optional parameters to initialize with previous token data
        accounts : ?[(Principal, [(Subaccount, Balance)])];

        // you can only add transactions if you 
        // have opted-in to store them.
        transactions : ?[Transaction];
    };

    public type SubaccountStore = StableTrieMap<Subaccount, Balance>;
    public type AccountStore =  StableTrieMap<Principal, SubaccountStore>;

    public type InternalData = {
        var name : Text;
        var symbol : Text;
        decimals : Nat8;
        var fee : Balance;
        max_supply : Balance;
        minting_account : Account;
        accounts : AccountStore;
        metadata : StableBuffer<MetaDatum>;
        supported_standards: StableBuffer<SupportedStandard>;
        transaction_window : Timestamp;

        store_transactions : Bool;
        transactions : StableBuffer<Transaction>;
    };

}