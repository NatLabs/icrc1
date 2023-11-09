import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import EC "mo:base/ExperimentalCycles";

import Itertools "mo:itertools/Iter";
import StableTrieMap "mo:StableTrieMap";

import Account "Account";
import T "Types";
import Utils "Utils";
import Transfer "Transfer";
import Archive "Canisters/Archive";

/// The ICRC1 class with all the functions for creating an
/// ICRC1 token on the Internet Computer
module {
    let { SB } = Utils;

    public type Account = T.Account;
    public type Subaccount = T.Subaccount;
    public type AccountBalances = T.AccountBalances;

    public type Transaction = T.Transaction;
    public type Balance = T.Balance;
    public type TransferArgs = T.TransferArgs;
    public type Mint = T.Mint;
    public type BurnArgs = T.BurnArgs;
    public type TransactionRequest = T.TransactionRequest;
    public type TransferError = T.TransferError;

    public type SupportedStandard = T.SupportedStandard;

    public type InitArgs = T.InitArgs;
    public type TokenInitArgs = T.TokenInitArgs;
    public type TokenData = T.TokenData;
    public type MetaDatum = T.MetaDatum;
    public type TxLog = T.TxLog;
    public type TxIndex = T.TxIndex;

    public type TokenInterface = T.TokenInterface;
    public type RosettaInterface = T.RosettaInterface;
    public type FullInterface = T.FullInterface;

    public type ArchiveInterface = T.ArchiveInterface;

    public type GetTransactionsRequest = T.GetTransactionsRequest;
    public type GetTransactionsResponse = T.GetTransactionsResponse;
    public type QueryArchiveFn = T.QueryArchiveFn;
    public type TransactionRange = T.TransactionRange;
    public type ArchivedTransaction = T.ArchivedTransaction;

    public type TransferResult = T.TransferResult;
    public type SetTextParameterResult = T.SetTextParameterResult;
    public type SetBalanceParameterResult = T.SetBalanceParameterResult;
    public type SetNat8ParameterResult = T.SetNat8ParameterResult;
    public type SetAccountParameterResult = T.SetAccountParameterResult;

    public let MAX_TRANSACTIONS_IN_LEDGER = 2000;
    public let MAX_TRANSACTION_BYTES : Nat64 = 196;
    public let MAX_TRANSACTIONS_PER_REQUEST = 5000;

    /// Initialize a new ICRC-1 token
    public func init(args : T.InitArgs) : T.TokenData {
        let {
            name;
            symbol;
            decimals;
            fee;
            logo;
            minting_account;
            max_supply;
            initial_balances;
            min_burn_amount;
            advanced_settings;
        } = args;

        var _burned_tokens = 0;
        var permitted_drift = 60_000_000_000;
        var transaction_window = 86_400_000_000_000;

        switch(advanced_settings){
            case(?options) {
                _burned_tokens := options.burned_tokens;
                permitted_drift := Nat64.toNat(options.permitted_drift);
                transaction_window := Nat64.toNat(options.transaction_window);
            };
            case(null) { };
        };

        if (not Account.validate(minting_account)) {
            Debug.trap("minting_account is invalid");
        };

        let accounts : T.AccountBalances = StableTrieMap.new();

        var _minted_tokens = _burned_tokens;

        for ((i, (account, balance)) in Itertools.enumerate(initial_balances.vals())) {

            if (not Account.validate(account)) {
                Debug.trap(
                    "Invalid Account: Account at index " # debug_show i # " is invalid in 'initial_balances'",
                );
            };

            let encoded_account = Account.encode(account);

            StableTrieMap.put(
                accounts,
                Blob.equal,
                Blob.hash,
                encoded_account,
                balance,
            );

            _minted_tokens += balance;
        };

        {
            var _name = name;
            var _symbol = symbol;
            var _decimals = decimals;
            var _fee = fee;
            var _logo = logo;
            max_supply;
            var _minted_tokens = _minted_tokens;
            var _burned_tokens = _burned_tokens;
            var _min_burn_amount = min_burn_amount;
            var _minting_account = minting_account;
            accounts;
            metadata = Utils.init_metadata(args);
            supported_standards = Utils.init_standards();
            transactions = SB.initPresized(MAX_TRANSACTIONS_IN_LEDGER);
            permitted_drift;
            transaction_window;
            archive = {
                var canister = actor ("aaaaa-aa");
                var stored_txs = 0;
            };
        };
    };

    /// Retrieve the name of the token
    public func name(token : T.TokenData) : Text {
        token._name;
    };

    /// Retrieve the symbol of the token
    public func symbol(token : T.TokenData) : Text {
        token._symbol;
    };

    /// Retrieve the number of decimals specified for the token
    public func decimals(token : T.TokenData) : Nat8 {
        token._decimals;
    };

    /// Retrieve the fee for each transfer
    public func fee(token : T.TokenData) : T.Balance {
        token._fee;
    };

    /// Retrieve the minimum burn amount for the token
    public func min_burn_amount(token : T.TokenData) : T.Balance {
        token._min_burn_amount;
    };

    /// Set the name of the token
    public func set_name(token : T.TokenData, name : Text, caller : Principal) : async* T.SetTextParameterResult {
        if (caller == token._minting_account.owner) {
            token._name := name;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting name only allowed via minting account.";
                },
            );
        };
        #Ok(token._name);
    };

    /// Set the symbol of the token
    public func set_symbol(token : T.TokenData, symbol : Text, caller : Principal) : async* T.SetTextParameterResult {
        if (caller == token._minting_account.owner) {
            token._symbol := symbol;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting symbol only allowed via minting account.";
                },
            );
        };
        #Ok(token._symbol);
    };

    /// Set the logo for the token
    public func set_logo(token : T.TokenData, logo : Text, caller : Principal) : async* T.SetTextParameterResult {
        if (caller == token._minting_account.owner) {
            token._logo := logo;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting logo only allowed via minting account.";
                },
            );
        };
        #Ok(token._logo);
    };

    /// Set the fee for each transfer
    public func set_fee(token : T.TokenData, fee : Nat, caller : Principal) : async* T.SetBalanceParameterResult {
        if (caller == token._minting_account.owner) {
            if (fee >= 10_000 and fee <= 1_000_000_000) {
                token._fee := fee;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: fee must be a value between 10_000 and 1_000_000_000.";
                    },
                );
            };
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting fee only allowed via minting account.";
                },
            );
        };
        #Ok(token._fee);
    };

    /// Set the number of decimals specified for the token
    public func set_decimals(token : T.TokenData, decimals : Nat8, caller : Principal) : async* T.SetNat8ParameterResult {
        if (caller == token._minting_account.owner) {
            if (decimals >= 2 and decimals <= 12) {
                token._decimals := decimals;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: decimals must be a value between 2 and 12.";
                    },
                );
            };      
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting decimals only allowed via minting account.";
                },
            );
        };
        #Ok(token._decimals);
    };

    /// Set the minimum burn amount
    public func set_min_burn_amount(token : T.TokenData, min_burn_amount : Nat, caller : Principal) : async* T.SetBalanceParameterResult {
        if (caller == token._minting_account.owner) {
            if (min_burn_amount >= 10_000 and min_burn_amount <= 1_000_000_000_000) {
                token._min_burn_amount := min_burn_amount;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: minimum burn amount must be a value between 10_000 and 1_000_000_000_000.";
                    },
                );
            };   
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting minimum burn amount only allowed via minting account.";
                },
            );
        };
        #Ok(token._min_burn_amount);
    };

    /// Set the minting account
    public func set_minting_account(token : T.TokenData, minting_account : Text, caller : Principal) : async*  T.SetAccountParameterResult {
        if (caller == token._minting_account.owner) {
            token._minting_account := {
                owner = Principal.fromText(minting_account);
                subaccount = null;
            };
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting new minting account only allowed via current minting account.";
                },
            );
        };
        #Ok(token._minting_account);
    };

    /// Retrieve all the metadata of the token
    public func metadata(token : T.TokenData) : [T.MetaDatum] {
        [
            ("icrc1:fee", #Nat(token._fee)),
            ("icrc1:name", #Text(token._name)),
            ("icrc1:symbol", #Text(token._symbol)),
            ("icrc1:decimals", #Nat(Nat8.toNat(token._decimals))),
            ("icrc1:logo", #Text(token._logo))
        ]
    };

    /// Returns the current archive canister
    public func get_archive(token : T.TokenData) : T.ArchiveInterface {
        token.archive.canister;
    };    

    /// Returns the total number of transactions in the archive
    public func get_archive_stored_txs(token : T.TokenData) : Nat {
        token.archive.stored_txs;
    };    

    /// Returns the total supply of circulating tokens
    public func total_supply(token : T.TokenData) : T.Balance {
        token._minted_tokens - token._burned_tokens;
    };

    /// Returns the total supply of minted tokens
    public func minted_supply(token : T.TokenData) : T.Balance {
        token._minted_tokens;
    };

    /// Returns the total supply of burned tokens
    public func burned_supply(token : T.TokenData) : T.Balance {
        token._burned_tokens;
    };

    /// Returns the maximum supply of tokens
    public func max_supply(token : T.TokenData) : T.Balance {
        token.max_supply;
    };

    /// Returns the account with the permission to mint tokens
    ///
    /// Note: **The minting account can only participate in minting
    /// and burning transactions, so any tokens sent to it will be
    /// considered burned.**

    public func minting_account(token : T.TokenData) : T.Account {
        token._minting_account;
    };

    /// Retrieve the balance of a given account
    public func balance_of({ accounts } : T.TokenData, account : T.Account) : T.Balance {
        let encoded_account = Account.encode(account);
        Utils.get_balance(accounts, encoded_account);
    };

    /// Returns an array of standards supported by this token
    public func supported_standards(token : T.TokenData) : [T.SupportedStandard] {
        SB.toArray(token.supported_standards);
    };

    /// Formats a float to a nat balance and applies the correct number of decimal places
    public func balance_from_float(token : T.TokenData, float : Float) : T.Balance {
        if (float <= 0) {
            return 0;
        };

        let float_with_decimals = float * (10 ** Float.fromInt(Nat8.toNat(token._decimals)));

        Int.abs(Float.toInt(float_with_decimals));
    };

    /// Transfers tokens from one account to another account (minting and burning included)
    public func transfer(
        token : T.TokenData,
        args : T.TransferArgs,
        caller : Principal,
    ) : async* T.TransferResult {

        let from = {
            owner = caller;
            subaccount = args.from_subaccount;
        };

        let tx_kind = if (from == token._minting_account) {
            #mint
        } else if (args.to == token._minting_account) {
            #burn
        } else {
            #transfer
        };

        let tx_req = Utils.create_transfer_req(args, caller, tx_kind);

        switch (Transfer.validate_request(token, tx_req)) {
            case (#err(errorType)) {
                return #Err(errorType);
            };
            case (#ok(_)) {};
        };

        let { encoded; amount } = tx_req; 

        // process transaction
        switch(tx_req.kind){
            case(#mint){
                Utils.mint_balance(token, encoded.to, amount);
            };
            case(#burn){
                Utils.burn_balance(token, encoded.from, amount);
            };
            case(#transfer){
                Utils.transfer_balance(token, tx_req);

                // burn fee
                Utils.burn_balance(token, encoded.from, token._fee);
            };
        };

        // store transaction
        let index = SB.size(token.transactions) + token.archive.stored_txs;
        let tx = Utils.req_to_tx(tx_req, index);
        SB.add(token.transactions, tx);

        // transfer transaction to archive if necessary
        await* update_canister(token);

        #Ok(tx.index);
    };

    /// Helper function to mint tokens with minimum args
    public func mint(token : T.TokenData, args : T.Mint, caller : Principal) : async* T.TransferResult {													
        return #Err(
            #GenericError {
                error_code = 401;
                message = "Unauthorized: Minting not allowed.";
            },
        );
    };

    /// Helper function to burn tokens with minimum args
    public func burn(token : T.TokenData, args : T.BurnArgs, caller : Principal) : async* T.TransferResult {

        let transfer_args : T.TransferArgs = {
            args with to = token._minting_account;
            fee = null;
        };

        await* transfer(token, transfer_args, caller);
    };

    /// Returns the total number of transactions that have been processed by the given token.
    public func total_transactions(token : T.TokenData) : Nat {
        let { archive; transactions } = token;
        archive.stored_txs + SB.size(transactions);
    };

    /// Retrieves the transaction specified by the given `tx_index`
    public func get_transaction(token : T.TokenData, tx_index : T.TxIndex) : async* ?T.Transaction {
        let { archive; transactions } = token;

        let archived_txs = archive.stored_txs;

        if (tx_index < archive.stored_txs) {
            await archive.canister.get_transaction(tx_index);
        } else {
            let local_tx_index = (tx_index - archive.stored_txs) : Nat;
            SB.getOpt(token.transactions, local_tx_index);
        };
    };

    /// Retrieves the transactions specified by the given range
    public func get_transactions(token : T.TokenData, req : T.GetTransactionsRequest) : T.GetTransactionsResponse {
        let { archive; transactions } = token;

        var first_index = 0xFFFF_FFFF_FFFF_FFFF; // returned if no transactions are found

        let req_end = req.start + req.length;
        let tx_end = archive.stored_txs + SB.size(transactions);

        var txs_in_canister: [T.Transaction] = [];
        
        if (req.start < tx_end and req_end >= archive.stored_txs) {
            first_index := Nat.max(req.start, archive.stored_txs);
            let tx_start_index = (first_index - archive.stored_txs) : Nat;

            txs_in_canister:= SB.slice(transactions, tx_start_index, req.length);
        };

        let archived_range = if (req.start < archive.stored_txs) {
            {
                start = req.start;
                end = Nat.min(
                    archive.stored_txs,
                    (req.start + req.length) : Nat,
                );
            };
        } else {
            { start = 0; end = 0 };
        };

        let txs_in_archive = (archived_range.end - archived_range.start) : Nat;

        let size = Utils.div_ceil(txs_in_archive, MAX_TRANSACTIONS_PER_REQUEST);

        let archived_transactions = Array.tabulate(
            size,
            func(i : Nat) : T.ArchivedTransaction {
                let offset = i * MAX_TRANSACTIONS_PER_REQUEST;
                let start = offset + archived_range.start;
                let length = Nat.min(
                    MAX_TRANSACTIONS_PER_REQUEST,
                    archived_range.end - start,
                );

                let callback = token.archive.canister.get_transactions;

                { start; length; callback };
            },
        );

        {
            log_length = txs_in_archive + txs_in_canister.size();
            first_index;
            transactions = txs_in_canister;
            archived_transactions;
        };
    };

    // Updates the token's data and manages the transactions
    //
    // **added at the end of any function that creates a new transaction**
    func update_canister(token : T.TokenData) : async* () {
        let txs_size = SB.size(token.transactions);

        if (txs_size >= MAX_TRANSACTIONS_IN_LEDGER) {
            await* append_transactions(token);
        };
    };

    // Moves the transactions from the ICRC1 canister to the archive canister
    // and returns a boolean that indicates the success of the data transfer
    func append_transactions(token : T.TokenData) : async* () {
        let { archive; transactions } = token;

        if (archive.stored_txs == 0) {
            EC.add(200_000_000_000);
            archive.canister := await Archive.Archive();
        } else { 
            let add = await* should_add_archive(token);
            if (add == 1) {
                await* add_archive(token);
            };
        };

        let res = await archive.canister.append_transactions(
            SB.toArray(transactions),
        );

        switch (res) {
            case (#ok(_)) {
                archive.stored_txs += SB.size(transactions);
                SB.clear(transactions);
            };
            case (#err(_)) {};
        };
    };

    func should_add_archive(token : T.TokenData) : async* Nat {
        let { archive } = token;
        let total_used = await archive.canister.total_used();
        let remaining_capacity = await archive.canister.remaining_capacity();

        if ( total_used >= remaining_capacity ) {
            return 1;
        };

        0;
    };    

    // Creates a new archive canister
    func add_archive(token : T.TokenData) : async* () {
        let { archive; transactions } = token;

        let oldCanister = archive.canister;
        let old_total_tx : Nat = await oldCanister.total_transactions();
        let old_first_tx : Nat = await oldCanister.get_first_tx();
        let old_last_tx : Nat = old_first_tx + old_total_tx - 1;
                // last_tx == SB.size(token.transactions) + token.archive.stored_txs

        let res1 = await oldCanister.set_last_tx(old_last_tx);

        EC.add(200_000_000_000);
        let newCanister = await Archive.Archive();

        let res2 = await oldCanister.set_next_archive(newCanister);
        let res3 = await newCanister.set_prev_archive(oldCanister);

        let res4 = await newCanister.set_first_tx(old_last_tx + 1);

        archive.canister := newCanister;
    };
};
