

module{

    //Cycles required for initital deployment
    public let TOKEN_INITIAL_DEPLOYMENT_CYCLES_REQUIRED = 2_900_000_000_000;

    //Cycles needed from inside the init method
    public let TOKEN_INITIAL_CYCLES_REQUIRED = 2_000_000_000_000;

    public let TOKEN_CANISTERS_MINIMUM_CYCLES_TO_KEEP = 500_000_000_000;

    public let ARCHIVE_CANISTERS_MINIMUM_CYCLES_REQUIRED = 100_000_000_000;
                    
    //Number of transactions to keep in token-cache until they are transfered into archive-canister
    public let MAX_TRANSACTIONS_IN_LEDGER = 2000;
        
    //The maximum number of transactions returned by request of 'get_transactions'
    public let MAX_TRANSACTIONS_PER_REQUEST = 5000;

};