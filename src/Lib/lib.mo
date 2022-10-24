import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Result "mo:base/Result";

import Itertools "mo:Itertools/Iter";
import StableBuffer "mo:StableBuffer/StableBuffer";
import STMap "mo:StableTrieMap";

import Archive "Archive";
import Validate "Validate";
import T "Types";
import U "Utils";

module ICRC1 {
    public let { SB } = U;
    public type StableTrieMap<K, V> = STMap.StableTrieMap<K, V>;
    public type StableBuffer<T> = StableBuffer.StableBuffer<T>;

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

        let accounts : AccountStore = STMap.new(Principal.equal, Principal.hash);
        STMap.put(
            accounts,
            minting_account.owner,
            U.new_subaccount_map(
                minting_account.subaccount,
                max_supply,
            ),
        );

        for ((owner, sub_balances) in initial_balances.vals()) {
            let sub_map : T.SubaccountStore = STMap.new(Blob.equal, Blob.hash);

            for ((subaccount, balance) in sub_balances.vals()) {
                if (not Validate.subaccount(?subaccount)) {
                    Debug.trap(
                        "Invalid subaccount " # Principal.toText(Principal.fromBlob(subaccount)) # " for " # Principal.toText(owner) # " is invalid in initial_balances",
                    );
                };

                STMap.put(sub_map, subaccount, balance);
            };

            STMap.put(accounts, owner, sub_map);

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
            var tx_deduplication = true;
            transaction_window = U.DAY_IN_NANO_SECONDS;
            archives = SB.init();
        };
    };

    public func name(token : TokenData) : Text {
        token.name;
    };

    public func symbol(token : TokenData) : Text {
        token.symbol;
    };

    public func decimals({ decimals } : TokenData) : Nat8 {
        decimals;
    };

    public func fee(token : TokenData) : Balance {
        token.fee;
    };

    public func set_fee(token : TokenData, fee : Nat) {
        token.fee := fee;
    };

    public func metadata(token : TokenData) : [MetaDatum] {
        SB.toArray(token.metadata);
    };

    public func total_supply(token : TokenData) : Balance {
        let {
            max_supply;
            accounts;
            minting_account;
        } = token;

        max_supply - U.get_balance(accounts, minting_account);
    };

    public func minting_account(token : TokenData) : Account {
        token.minting_account;
    };

    public func balance_of({ accounts } : TokenData, req : Account) : Balance {
        U.get_balance(accounts, req);
    };

    public func supported_standards(token : TokenData) : [SupportedStandard] {
        SB.toArray(token.supported_standards);
    };

    public func add_supported_standard(token : TokenData, standard : T.SupportedStandard) {
        SB.add(token.supported_standards, standard);
    };

    public func set_tx_deduplication(token : TokenData, val : Bool) {
        token.tx_deduplication := val;
    };

    public func mint(token : TokenData, args : Mint, caller : Principal) : async Result.Result<Balance, TransferError> {

        if (not (caller == token.minting_account.owner)) {
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
                if (not (token.fee == fee)) {
                    return #err(
                        #BadFee {
                            expected_fee = token.fee;
                        },
                    );
                };
            };

            case (_) {
                if (not (token.fee == 0)) {
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

    public func total_transactions(token : TokenData) : Nat {
        SB.size(token.transactions) + U.total_archived_txs(token.archives);
    };

    public func get_transaction(token : TokenData, tx_index : ICRC1.TxIndex) : async ?ICRC1.Transaction {
        let archived_txs = U.total_archived_txs(token.archives);
        if (tx_index < archived_txs) {

            let archive = Itertools.find(
                SB.toIter(token.archives),
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
        label _loop for (archive in SB.toIter(token.archives)) {
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

                if (not (new_data == old_data)) {
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

    // Moves the transactions in the ICRC1 canister to the archive canister
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
