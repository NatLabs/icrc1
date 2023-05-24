import Types1 "../ICRC1/Types";

module {

    public type Value = Types1.Value;

    public type BlockIndex = Types1.BlockIndex;
    public type Subaccount = Types1.Subaccount;
    public type Balance = Types1.Balance;
    public type StableBuffer<T> = Types1.StableBuffer<T>;
    public type StableTrieMap<K, V> = Types1.StableTrieMap<K, V>;

    public type Account = Types1.Account;

    public type EncodedAccount = Types1.EncodedAccount;

    public type SupportedStandard = Types1.SupportedStandard;

    public type Memo = Types1.Memo;
    public type Timestamp = Types1.Timestamp;
    public type Duration = Types1.Duration;
    public type TxIndex = Types1.TxIndex;
    public type TxLog = Types1.TxLog;

    public type MetaDatum = Types1.MetaDatum;
    public type MetaData = [MetaDatum];

    public type TxKind = Types1.TxKind;

    public type Mint = Types1.Mint;

    public type BurnArgs = Types1.BurnArgs;

    public type Burn = Types1.Burn;

    public type TransferArgs = Types1.TransferArgs;

    public type Transfer = Types1.Transfer;

    /// Internal representation of a transaction request
    public type TransactionRequest = Types1.TransactionRequest;

    public type Transaction = Types1.Transaction;

    public type TimeError = Types1.TimeError;

    public type TransferError = Types1.TransferError;

    public type TransferResult = Types1.TransferResult;

    /// Interface for the ICRC token canister
    public type TokenInterface = Types1.TokenInterface;

    public type TxCandidBlob = Types1.TxCandidBlob;

    /// The Interface for the Archive canister
    public type ArchiveInterface = Types1.ArchiveInterface;

    /// Initial arguments for the setting up the icrc2 token canister
    public type InitArgs = Types1.InitArgs;

    /// [InitArgs](#type.InitArgs) with optional fields for initializing a token canister
    public type TokenInitArgs = Types1.TokenInitArgs;

    /// Additional settings for the [InitArgs](#type.InitArgs) type during initialization of an icrc2 token canister
    public type AdvancedSettings = Types1.AdvancedSettings;

    public type AccountBalances = Types1.AccountBalances;

    /// The details of the archive canister
    public type ArchiveData = Types1.ArchiveData;

    /// The state of the token canister
    public type TokenData = Types1.TokenData;

    // Rosetta API
    /// The type to request a range of transactions from the ledger canister
    public type GetTransactionsRequest = Types1.GetTransactionsRequest;

    public type TransactionRange = Types1.TransactionRange;

    public type QueryArchiveFn = Types1.QueryArchiveFn;

    public type ArchivedTransaction = Types1.ArchivedTransaction;

    public type GetTransactionsResponse = Types1.GetTransactionsResponse;

    /// Functions supported by the rosetta
    public type RosettaInterface = Types1.RosettaInterface;

    /// Interface of the ICRC token and Rosetta canister
    public type FullInterface = TokenInterface and RosettaInterface;

};
