import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Result "mo:base/Result";

import Itertools "mo:Itertools/Iter";
import StableTrieMap "mo:StableTrieMap";

import Account "Account";
import Archive "Archive";
import T "Types";
import U "Utils";
import Validate "Validate";

/// The ICRC1 Module with all the functions for creating an
/// ICRC1 token on the Internet Computer
module ICRC1 {
    public let { SB } = U;

    public type Account = T.Account;
    public type Subaccount = T.Subaccount;
    public type AccountStore = T.AccountStore;

    public type Transaction = T.Transaction;
    public type Balance = T.Balance;
    public type TransferArgs = T.TransferArgs;
    public type Mint = T.Mint;
    public type BurnArgs = T.BurnArgs;
    public type TransactionRequest = T.TransactionRequest;
    public type TransferError = T.TransferError;

    public type SupportedStandard = T.SupportedStandard;

    public type InitArgs = T.InitArgs;
    public type TokenData = T.TokenData;
    public type MetaDatum = T.MetaDatum;
    public type TxLog = T.TxLog;
    public type TxIndex = T.TxIndex;

    public type TokenInterface = T.TokenInterface;

    public type ArchiveInterface = T.ArchiveInterface;

    public type GetTransactionsRequest = T.GetTransactionsRequest;
    public type GetTransactionsResponse = T.GetTransactionsResponse;
    public type QueryArchiveFn = T.QueryArchiveFn;
    public type ArchivedTransaction = T.ArchivedTransaction;

    public let MAX_TRANSACTIONS_IN_LEDGER = 2000;
    public let MAX_TRANSACTION_BYTES : Nat64 = 196;
    public let MAX_TRANSACTIONS_PER_REQUEST = 5000;

    /// Initialize a new ICRC-1 token
    public func init(args : InitArgs) : TokenData {
        let {
            name;
            symbol;
            decimals;
            fee;
            minting_account;
            max_supply;
            initial_balances;
        } = args;

        if (not Validate.account(minting_account)) {
            Debug.trap("minting_account is invalid");
        };

        if (max_supply < 10 ** Nat8.toNat(decimals)) {
            Debug.trap("max_supply must be >= 1");
        };

        let accounts : AccountStore = StableTrieMap.new();
        StableTrieMap.put(
            accounts,
            Blob.equal,
            Blob.hash,
            Account.encode(minting_account),
            max_supply,
        );

        for ((i, (account, balance)) in Itertools.enumerate(initial_balances.vals())) {

            if (not Validate.account(account)) {
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
        };

        {
            name = name;
            symbol = symbol;
            decimals;
            var fee = fee;
            max_supply;
            minting_account;
            accounts;
            metadata = U.init_metadata(args);
            supported_standards = U.init_standards();
            transactions = SB.initPresized(MAX_TRANSACTIONS_IN_LEDGER);
            permitted_drift = 2 * 60 * 1000;
            transaction_window = Nat64.toNat(U.DAY_IN_NANO_SECONDS);
            archives = SB.init();
        };
    };

    /// Retrieve the name of the token
    public func name(token : TokenData) : Text {
        token.name;
    };

    /// Retrieve the symbol of the token
    public func symbol(token : TokenData) : Text {
        token.symbol;
    };

    /// Retrieve the number of decimals specified for the token
    public func decimals({ decimals } : TokenData) : Nat8 {
        decimals;
    };

    /// Retrieve the fee for each transfer
    public func fee(token : TokenData) : Balance {
        token.fee;
    };

    /// Set the fee for each transfer
    public func set_fee(token : TokenData, fee : Nat) {
        token.fee := fee;
    };

    /// Retrieve all the metadata of the token
    public func metadata(token : TokenData) : [MetaDatum] {
        SB.toArray(token.metadata);
    };

    /// Returns the total supply of circulating tokens
    public func total_supply(token : TokenData) : Balance {
        let {
            max_supply;
            accounts;
            minting_account;
        } = token;

        let encoded_account = Account.encode(minting_account);
        max_supply - U.get_balance(accounts, encoded_account);
    };

    /// Returns the account with the permission to mint tokens
    ///
    /// Note: **The minting account can only participate in minting
    /// and burning transactions, so any tokens sent to it will be
    /// considered burned.**

    public func minting_account(token : TokenData) : Account {
        token.minting_account;
    };

    /// Retrieve the balance of a given account
    public func balance_of({ accounts } : TokenData, account : Account) : Balance {
        let encoded_account = Account.encode(account);
        U.get_balance(accounts, encoded_account);
    };

    /// Returns an array of standards supported by this token
    public func supported_standards(token : TokenData) : [SupportedStandard] {
        SB.toArray(token.supported_standards);
    };

    /// Add a standard to the standards supported of the given token
    public func add_supported_standard(token : TokenData, standard : T.SupportedStandard) {
        SB.add(token.supported_standards, standard);
    };

    /// Custom function to mint tokens with minimal function parameters
    public func mint(token : TokenData, args : Mint, caller : Principal) : async Result.Result<Balance, TransferError> {

        if (caller != token.minting_account.owner) {
            return #err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Only the minting_account can mint tokens.";
                },
            );
        };

        let tx_req = U.args_to_req(
            #mint(args),
            token.minting_account,
        );

        switch (Validate.transfer(token, tx_req)) {
            case (#err(errorType)) {
                return #err(errorType);
            };
            case (_) {};
        };

        ignore U.process_tx(token, tx_req);

        await update_canister(token);

        #ok(tx_req.amount);
    };

    /// Custom function to burn tokens with minimal function parameters
    public func burn(token : TokenData, args : BurnArgs, caller : Principal) : async Result.Result<Balance, TransferError> {

        let burn_op : T.Burn = {
            args with from = {
                owner = caller;
                subaccount = args.from_subaccount;
            };
        };

        let tx_req = U.args_to_req(
            #burn(burn_op),
            token.minting_account,
        );

        switch (Validate.transfer(token, tx_req)) {
            case (#err(errorType)) {
                return #err(errorType);
            };
            case (_) {};
        };

        ignore U.process_tx(token, tx_req);

        await update_canister(token);

        #ok(tx_req.amount);
    };

    /// Transfers tokens from one account to another
    public func transfer(
        token : TokenData,
        args : TransferArgs,
        caller : Principal,
    ) : async Result.Result<Balance, TransferError> {
        let {
            accounts;
            minting_account;
            transaction_window;
        } = token;

        let transfer_op : T.Transfer = {
            args with from = {
                owner = caller;
                subaccount = args.from_subaccount;
            };
        };

        switch (args.fee) {
            case (?fee) {
                if (token.fee != fee) {
                    return #err(
                        #BadFee {
                            expected_fee = token.fee;
                        },
                    );
                };
            };

            case (_) {
                if (token.fee != 0) {
                    return #err(
                        #BadFee {
                            expected_fee = token.fee;
                        },
                    );
                };
            };
        };

        var tx_req = U.args_to_req(
            #transfer(transfer_op),
            token.minting_account,
        );

        let { from; to } = tx_req;

        switch (Validate.transfer(token, tx_req)) {
            case (#err(errorType)) {
                return #err(errorType);
            };
            case (#ok(_)) {};
        };

        if (from == minting_account) {
            tx_req := { tx_req with kind = #mint };
        } else if (to == minting_account) {
            tx_req := { tx_req with kind = #burn };
        };

        ignore U.process_tx(token, tx_req);

        await update_canister(token);

        #ok(tx_req.amount);
    };

    /// Returns the total number of transactions that have been processed by the given token.
    public func total_transactions(token : TokenData) : Nat {
        SB.size(token.transactions) + U.total_archived_txs(token.archives);
    };

    /// Retrieves the transaction specified by the given `tx_index`
    public func get_transaction(token : TokenData, tx_index : ICRC1.TxIndex) : async ?ICRC1.Transaction {
        let archived_txs = U.total_archived_txs(token.archives);
        if (tx_index < archived_txs) {

            let archive = Itertools.find(
                SB.vals(token.archives),
                func({ start; length } : T.ArchiveData) : Bool {
                    let end = start + length;

                    tx_index < end;
                },
            );

            switch (archive) {
                case (?archive) {
                    await archive.canister.get_transaction(tx_index);
                };
                case (_) { null };
            };

        } else {
            let local_tx_index = (tx_index - archived_txs) : Nat;
            SB.getOpt(token.transactions, local_tx_index);
        };
    };

    func get_local_txs(
        token : TokenData,
        { start; length } : GetTransactionsRequest,
    ) : Iter.Iter<Transaction> {
        SB.toIterFromSlice(token.transactions, start, start + length);
    };

    func get_txs(token : TokenData, req : T.GetTransactionsRequest) : async [Transaction] {
        var txs_size = 0;
        var txs_iter = Itertools.empty<Transaction>();
        let expected_size = Nat.min(req.length, MAX_TRANSACTIONS_PER_REQUEST);

        // Gets transactions in the request range from archive canisters
        label _loop for (archive in SB.vals(token.archives)) {
            let archive_end = archive.start + archive.length;

            if (req.start < archive_end) {
                let _txs = await archive.canister.get_transactions({
                    start = Nat.max(req.start, archive.start);
                    length = expected_size - txs_size;
                });

                txs_size += _txs.size();
                txs_iter := Itertools.chain(txs_iter, _txs.vals());
            };

            if (txs_size == expected_size) {
                break _loop;
            };
        };

        if (txs_size < expected_size) {
            let archived_txs = U.total_archived_txs(token.archives);

            let local_txs = get_local_txs(token, { start = 0; length = expected_size - txs_size });

            txs_iter := Itertools.chain(txs_iter, local_txs);
        };

        Iter.toArray(txs_iter);
    };

    /// Retrieves the transactions specified by the given range
    public func get_transactions(token : TokenData, req : ICRC1.GetTransactionsRequest) : async ICRC1.GetTransactionsResponse {
        let { archives } = token;

        let txs = await get_txs(token, req);

        let valid_range = {
            var start = req.start + txs.size();
            var end = Nat.min(req.start + txs.size() + req.length, total_transactions(token));
        };

        let size = (valid_range.end - valid_range.start) : Nat / MAX_TRANSACTIONS_PER_REQUEST;
        let paginated_requests = Array.tabulate(
            size,
            func(i : Nat) : GetTransactionsRequest {
                let offset = i * MAX_TRANSACTIONS_PER_REQUEST;
                let start = offset + valid_range.start;

                {
                    start;
                    length = Nat.min(MAX_TRANSACTIONS_PER_REQUEST, valid_range.end - start);
                };
            },
        );

        {
            log_length = txs.size();
            first_index = req.start;
            transactions = txs;
            archived_transactions = paginated_requests;
        };

    };

    // Retrieves the last archive in the archives buffer
    func get_last_archive(token : TokenData) : ?T.ArchiveData {
        SB.getLast(token.archives);
    };

    // creates a new archive canister
    func new_archive_canister() : async ArchiveInterface {
        await Archive.Archive({
            max_memory_size_bytes = MAX_TRANSACTION_BYTES;
        });
    };

    // Adds a new archive canister to the archives array
    func spawn_archive_canister(token : TokenData) : async () {

        let start = switch (get_last_archive(token)) {
            case (?archive) {
                archive.start + archive.length;
            };
            case (_) {
                0;
            };
        };

        let new_archive : T.ArchiveData = {
            start;
            length = 0;
            canister = await new_archive_canister();
        };

        SB.add(token.archives, new_archive);
    };

    // Updates the last archive in the archives buffer
    func update_last_archive(token : TokenData, update : (T.ArchiveData) -> async T.ArchiveData) : async () {
        switch (get_last_archive(token)) {
            case (?old_data) {
                let new_data = await update(old_data);

                if (new_data != old_data) {
                    SB.put(
                        token.archives,
                        SB.size(token.archives) - 1,
                        new_data,
                    );
                };
            };
            case (_) {};
        };
    };

    // Moves the transactions from the ICRC1 canister to the archive canister
    // and returns a boolean that indicates the success of the data transfer
    func append_to_archive(token : TokenData) : async Bool {
        var success = false;

        await update_last_archive(
            token,
            func(archive : T.ArchiveData) : async T.ArchiveData {
                let { canister; length } = archive;
                let res = await canister.append_transactions(
                    SB.toArray(token.transactions),
                );

                var txs_size = SB.size(token.transactions);

                switch (res) {
                    case (#ok()) {
                        SB.clear(token.transactions);
                        success := true;
                    };
                    case (#err(_)) {
                        txs_size := 0;
                    };
                };

                { archive with length = length + txs_size };
            },
        );

        success;
    };

    // Updates the token's data and manages the transactions
    //
    // **should be added at the end of every update call**
    func update_canister(token : TokenData) : async () {
        let { archives } = token;

        let txs_size = SB.size(token.transactions);

        if (txs_size >= MAX_TRANSACTIONS_IN_LEDGER) {
            if (SB.size(archives) == 0) {
                await spawn_archive_canister(token);
            };

            if (not (await append_to_archive(token))) {
                await spawn_archive_canister(token);
                ignore (await append_to_archive(token));
            };
        };
    };
};
