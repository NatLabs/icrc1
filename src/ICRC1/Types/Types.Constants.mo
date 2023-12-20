

module{

    ///Cycles required for initital deployment
    public let TOKEN_INITIAL_DEPLOYMENT_CYCLES_REQUIRED = 2_900_000_000_000;

    ///Cycles needed from inside the init method
    public let TOKEN_INITIAL_CYCLES_REQUIRED = 2_000_000_000_000;

    ///The main token will only auto top-up to archive canister if main token holds at least this amount
    public let TOKEN_CANISTERS_MINIMUM_CYCLES_TO_KEEP = 500_000_000_000;

    ///If the archive canister holds less cycles than this amount, then it will be auto filled if auto-topup timer is enabled in token.mo
    public let ARCHIVE_CANISTERS_MINIMUM_CYCLES_REQUIRED = 100_000_000_000;
                    
    ///Number of transactions to keep in token-cache until they are transfered into archive-canister
    public let MAX_TRANSACTIONS_IN_LEDGER = 2000;
        
    ///The maximum number of transactions returned by request of 'get_transactions'
    public let MAX_TRANSACTIONS_PER_REQUEST = 5000;

};