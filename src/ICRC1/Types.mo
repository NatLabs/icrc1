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

    /// Max size
    /// kind : 8 chars (8 * 32 /8) -> 32
    /// from : (32 + 32) -> 68 B
    /// to : 68  B
    /// fee : Nat64 -> 8 B
    /// amount : Nat128 -> 16 B
    /// memo: 32 -> 4 B
    /// time : Nat64 -> 8 B
    /// ---------------------------
    /// total : 196 Bytes
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
        icrc1_name : query () -> async Text;

        /// Returns the symbol of the token
        icrc1_symbol : query () -> async Text;

        icrc1_decimals : query () -> async Nat8;

        icrc1_fee : query () -> async Balance;

        icrc1_metadata : query () -> async MetaData;

        icrc1_total_supply : query () -> async Balance;

        icrc1_minting_account : query () -> async ?Account;

        icrc1_balance_of : query (Account) -> async Balance;

        icrc1_transfer : (TransferArgs) -> async Result.Result<Balance, TransferError>;

        icrc1_supported_standards : query () -> async [SupportedStandard];

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
        transaction_window : ?Time.Time;
        initial_balances : [(Account, Balance)];
        // archive_options : {
        //     num_blocks_to_archive : Nat;
        //     trigger_threshold : Nat;
        //     controller_id : Principal;
        // };
    };

    public type ExportedArgs = InitArgs and {
        /// Time between when a transaction is created on the frontend
        /// and sent to the canister for execution.
        /// **This value should be in seconds**
        transaction_window : ?Timestamp;

        // The minting_account defaults to account of the
        // canister if its null
        minting_account : ?Account;
        metadata : ?MetaData;
        supported_standards : ?[SupportedStandard];

        // optional parameters to initialize with previous token data
        accounts : ?[(Principal, [(Subaccount, Balance)])];

        // you can only add transactions if you
        // have opted-in to store them.
        transactions : ?[Transaction];
    };

    public type SubaccountStore = StableTrieMap<Subaccount, Balance>;
    public type AccountStore = StableTrieMap<EncodedAccount, Balance>;

    public type TransactionRange = {
        start : TxIndex;
        length : Nat;
    };

    public type ArchiveData = {
        canister : ArchiveInterface;
    } and TransactionRange;

    public type TokenData = {
        name : Text;
        symbol : Text;
        decimals : Nat8;
        var fee : Balance;
        max_supply : Balance;
        minting_account : Account;
        accounts : AccountStore;
        metadata : StableBuffer<MetaDatum>;
        supported_standards : StableBuffer<SupportedStandard>;
        transaction_window : Nat;
        permitted_drift : Nat;
        transactions : StableBuffer<Transaction>;
        archives : StableBuffer<ArchiveData>;
    };

    // TxLog
    /// A prefix array of the transaction range specified in the [GetTransactionsRequest](./#GetTransactionsRequest) request.

    public type GetTransactionsRequest = TransactionRange;

    public type QueryArchiveFn = (GetTransactionsRequest) -> async ([Transaction]);

    public type ArchivedTransaction = {
        start : TxIndex;
        length : Nat;
    };

    public type GetTransactionsResponse = {
        log_length : Nat;

        // the index of the first tx in `.transactions`
        first_index : TxIndex;

        // The first prefix of transactions in the given range
        transactions : [Transaction];

        // the remaining sub array of transactions in the given range
        archived_transactions : [ArchivedTransaction];
    };

};
