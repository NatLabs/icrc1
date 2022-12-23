import Deque "mo:base/Deque";
import List "mo:base/List";
import Time "mo:base/Time";
import Result "mo:base/Result";

import STMap "mo:StableTrieMap";
import StableBuffer "mo:StableBuffer/StableBuffer";

module {

    public type Value = { #Nat : Nat; #Int : Int; #Blob : Blob; #Text : Text };

    public type BlockIndex = Nat;
    public type Subaccount = Blob;
    public type Balance = Nat;
    public type StableBuffer<T> = StableBuffer.StableBuffer<T>;
    public type StableTrieMap<K, V> = STMap.StableTrieMap<K, V>;

    public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
    };

    public type EncodedAccount = Blob;

    public type SupportedStandard = {
        name : Text;
        url : Text;
    };

    public type Memo = Blob;
    public type Timestamp = Nat64;
    public type Duration = Nat64;
    public type TxIndex = Nat;
    public type TxLog = StableBuffer<Transaction>;

    public type MetaDatum = (Text, Value);
    public type MetaData = [MetaDatum];

    public type OperationKind = {
        #mint;
        #burn;
        #transfer;
    };

    public type Mint = {
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

    public type Burn = {
        from : Account;
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

    public type Transfer = {
        from : Account;
        to : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type Operation = {
        #mint : Mint;
        #burn : Burn;
        #transfer : Transfer;
    };

    public type TransactionRequest = {
        kind : OperationKind;
        from : Account;
        to : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
        encoded : {
            from : EncodedAccount;
            to : EncodedAccount;
        };
    };

    public type Transaction = {
        kind : Text;
        mint : ?Mint;
        burn : ?Burn;
        transfer : ?Transfer;
        timestamp : Timestamp;
    };

    public type TimeError = {
        #TooOld;
        #CreatedInFuture : { ledger_time : Timestamp };
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
    public type TokenInterface = actor {

        /// Returns the name of the token
        icrc1_name : shared query () -> async Text;

        /// Returns the symbol of the token
        icrc1_symbol : shared query () -> async Text;

        icrc1_decimals : shared query () -> async Nat8;

        icrc1_fee : shared query () -> async Balance;

        icrc1_metadata : shared query () -> async MetaData;

        icrc1_total_supply : shared query () -> async Balance;

        icrc1_minting_account : shared query () -> async ?Account;

        icrc1_balance_of : shared query (Account) -> async Balance;

        icrc1_transfer : shared (TransferArgs) -> async Result.Result<Balance, TransferError>;

        icrc1_supported_standards : shared query () -> async [SupportedStandard];

    };

    public type TxCandidBlob = Blob;

    public type ArchiveInterface = actor {
        append_transactions : shared ([Transaction]) -> async Result.Result<(), Text>;
        total_transactions : shared query () -> async Nat;
        get_transaction : shared query (TxIndex) -> async ?Transaction;
        get_transactions : shared query (GetTransactionsRequest) -> async [Transaction];
        remaining_capacity : shared query () -> async Nat;
    };

    public type InitArgs = {
        name : Text;
        symbol : Text;
        decimals : Nat8;
        fee : Balance;
        minting_account : Account;
        max_supply : Balance;
        initial_balances : [(Account, Balance)];
        transaction_window : ?Timestamp;
        permitted_drift : ?Timestamp;
    };

    /// Init Args with optional fields for the token actor canister
    public type TokenInitArgs = {
        name : Text;
        symbol : Text;
        decimals : Nat8;
        fee : Balance;
        max_supply : Balance;

        /// optional value that defaults to the caller if not provided
        minting_account : ?Account;

        initial_balances : [(Account, Balance)];
        /// defaults to 1 hour
        permitted_drift : ?Timestamp;
        /// defaults to 1 day
        transaction_window : ?Timestamp;
    };

    public type AccountBalances = StableTrieMap<EncodedAccount, Balance>;

    public type ArchiveData = {
        var canister : ArchiveInterface;
        var stored_txs : Nat;
    };

    public type TokenData = {
        name : Text;
        symbol : Text;
        decimals : Nat8;
        var fee : Balance;
        max_supply : Balance;
        minting_account : Account;
        accounts : AccountBalances;
        metadata : StableBuffer<MetaDatum>;
        supported_standards : StableBuffer<SupportedStandard>;
        transaction_window : Nat;
        permitted_drift : Nat;
        transactions : StableBuffer<Transaction>;
        archive : ArchiveData;
    };

    // Rosetta API
    public type GetTransactionsRequest = {
        start : TxIndex;
        length : Nat;
    };

    public type TransactionRange = {
        transactions: [Transaction];
    };

    public type QueryArchiveFn = shared (GetTransactionsRequest) -> async TransactionRange;

    public type ArchivedTransaction = {
        start : TxIndex;
        length : Nat;
        callback: QueryArchiveFn;
    };


    public type GetTransactionsResponse = {
        log_length : Nat;

        // the index of the first tx in `.transactions`
        first_index : TxIndex;

        // The transactions in the ledger canister that are in the given range
        transactions : [Transaction];

        archived_transactions : [ArchivedTransaction];
    };

    public type ArchiveTxWithoutCallback = GetTransactionsRequest;

    /// This type is used in the library because shared types are only allowed as a public field of an actor
    public type TxResponseWithoutCallback = {
        log_length : Nat;

        // the index of the first tx in `.transactions`
        first_index : TxIndex;

        // The transactions in the ledger canister that are in the given range
        transactions : [Transaction];

        archived_transactions : [ArchiveTxWithoutCallback];
    };

    /// Functions supported by the rosetta 
    public type RosettaInterface = actor {
        get_transactions : shared query (GetTransactionsRequest) -> async GetTransactionsResponse;
    };

    /// Interface of the ICRC token and Rosetta canister
    public type FullInterface = TokenInterface and RosettaInterface;

};
