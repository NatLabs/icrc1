import CommonTypes "Types.Common";
import AccountTypes "Types.Account";
import TransactionTypes "Types.Transaction";
import STMap "mo:StableTrieMap";
import StableBuffer "mo:StableBuffer/StableBuffer";
import ArchiveTypes "Types.Archive";

module{

    private type GetTransactionsResponse = TransactionTypes.GetTransactionsResponse;
    private type GetTransactionsRequest = TransactionTypes.GetTransactionsRequest;
    private type TransferResult = TransactionTypes.TransferResult;
    private type TransferArgs = TransactionTypes.TransferArgs;
    private type Transaction = TransactionTypes.Transaction;

    private type ArchiveData = ArchiveTypes.ArchiveData;

    private type Value = CommonTypes.Value;
    private type Balance = CommonTypes.Balance;

    private type Account = AccountTypes.Account;    
    private type AccountBalances = AccountTypes.AccountBalances;
    private type StableBuffer<T> = StableBuffer.StableBuffer<T>;

    
    ///Single Metadata item-type
    public type MetaDatum = (Text, Value);
    
    ///This information is used by the token
    public type MetaData = [MetaDatum];
        
    /// Initial arguments for the setting up the icrc1 token canister
    public type InitArgs = {
        name : Text;
        symbol : Text;
        decimals : Nat8;
        fee : Balance;
        logo : Text;
        minting_account : Account;
        max_supply : Balance;
        initial_balances : [(Account, Balance)];
        min_burn_amount : Balance;
        //Only if set to true then minting is allowed
        minting_allowed : Bool;        
    };

    /// [InitArgs](#type.InitArgs) with optional fields for initializing a token canister
    public type TokenInitArgs = {
        name : Text;
        symbol : Text;
        decimals : Nat8;
        fee : Balance;
        logo : Text;
        max_supply : Balance;
        initial_balances : [(Account, Balance)];
        min_burn_amount : Balance;

        /// optional value that defaults to the caller if not provided
        minting_account : ?Account;

        //Only if set to true then minting is allowed
        minting_allowed : Bool;

    };

    /// The state of the token canister
    public type TokenData = {
        /// The name of the token
        var name : Text;

        /// The symbol of the token
        var symbol : Text;

        /// The number of decimals the token uses
        var decimals : Nat8;

        /// The fee charged for each transaction
        var fee : Balance;

        /// The logo for the token
        var logo : Text;

        /// The maximum supply of the token
        max_supply : Balance;

        /// The total amount of minted tokens
        var minted_tokens : Balance;

        // Only if this is set to true then minting is allowed for this token
        minting_allowed:Bool;

        /// The total amount of burned tokens
        var burned_tokens : Balance;

        /// The account that is allowed to mint new tokens
        /// On initialization, the maximum supply is minted to this account
        var minting_account : Account;

        /// The balances of all accounts
        accounts : AccountBalances;

        /// The metadata for the token
        metadata : StableBuffer<MetaDatum>;

        /// The standards supported by this token's implementation
        supported_standards : StableBuffer<SupportedStandard>;

        /// The time window in which duplicate transactions are not allowed
        transaction_window : Nat;

        /// The minimum amount of tokens that must be burned in a transaction
        var min_burn_amount : Balance;

        /// The allowed difference between the ledger time and the time of the device the transaction was created on
        permitted_drift : Nat;

        /// The recent transactions that have been processed by the ledger.
        /// Only the last 2000 transactions are stored before being archived.
        transactions : StableBuffer<Transaction>;

        /// The record that stores the details to the archive canister and number of transactions stored in it
        archive : ArchiveData;
        
    };

    public type SupportedStandard = {
        name : Text;
        url : Text;
    };

    public type SetParameterError = {
        #GenericError : { error_code : Nat; message : Text };
    };
        
    public type SetTextParameterResult = {
        #Ok : Text;
        #Err : SetParameterError;
    };
    
    public type SetNat8ParameterResult = {
        #Ok : Nat8;
        #Err : SetParameterError;
    };
    
    public type SetBalanceParameterResult = {
        #Ok : Balance;
        #Err : SetParameterError;
    };
    
    public type SetAccountParameterResult = {
        #Ok : Account;
        #Err : SetParameterError;
    };

    /// Interface for the ICRC token canister
    public type TokenInterface = actor {

        /// Returns the name of the token
        icrc1_name : shared query () -> async Text;

        /// Returns the symbol of the token
        icrc1_symbol : shared query () -> async Text;

        /// Returns the number of decimals the token uses
        icrc1_decimals : shared query () -> async Nat8;

        /// Returns the fee charged for each transfer
        icrc1_fee : shared query () -> async Balance;

        /// Returns the tokens metadata
        icrc1_metadata : shared query () -> async MetaData;

        /// Returns the total supply of the token
        icrc1_total_supply : shared query () -> async Balance;

        /// Returns the account that is allowed to mint new tokens
        icrc1_minting_account : shared query () -> async ?Account;

        /// Returns the balance of the given account
        icrc1_balance_of : shared query (Account) -> async Balance;

        /// Transfers the given amount of tokens from the sender to the recipient
        icrc1_transfer : shared (TransferArgs) -> async TransferResult;

        /// Returns the standards supported by this token's implementation
        icrc1_supported_standards : shared query () -> async [SupportedStandard];

    };


    /// Functions supported by the rosetta 
    public type RosettaInterface = actor {
        get_transactions : shared query (GetTransactionsRequest) -> async GetTransactionsResponse;
    };

    /// Interface of the ICRC token and Rosetta canister
    public type FullInterface = TokenInterface and RosettaInterface;


};