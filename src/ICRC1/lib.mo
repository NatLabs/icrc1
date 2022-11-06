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

import ArchiveApi "ArchiveApi";
import Account "Account";
import T "Types";
import U "Utils";
import Transfer "Transfer";

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

        if (not Account.validate(minting_account)) {
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
        max_supply - Account.get_balance(accounts, encoded_account);
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
        Account.get_balance(accounts, encoded_account);
    };

    /// Returns an array of standards supported by this token
    public func supported_standards(token : TokenData) : [SupportedStandard] {
        SB.toArray(token.supported_standards);
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

        let transfer_args : T.Transfer = {
            args with from = {
                owner = caller;
                subaccount = args.from_subaccount;
            };
        };

        let { from; to } = transfer_args;

        let op = if (from == minting_account) {
            #mint(transfer_args);
        } else if (to == minting_account) {
            #burn(transfer_args);
        } else {
            #transfer(transfer_args);
        };

        let tx_req = U.args_to_req(
            op,
            token.minting_account,
        );

        if (tx_req.kind == #transfer) {
            if (tx_req.fee != ?token.fee) {
                return #err(
                    #BadFee {
                        expected_fee = token.fee;
                    },
                );
            };
        };

        switch (Transfer.validate_request(token, tx_req)) {
            case (#err(errorType)) {
                return #err(errorType);
            };
            case (#ok(_)) {};
        };

        // All checks passed.
        // now the transaction can be processed

        Account.transfer_balance(token.accounts, tx_req);

        // store transaction
        let tx = U.req_to_tx(tx_req);
        SB.add(token.transactions, tx);

        await update_canister(token);

        #ok(tx_req.amount);
    };

    /// Helper function to mint tokens with minimum args
    public func mint(token : TokenData, args : Mint, caller : Principal) : async Result.Result<Balance, TransferError> {

        if (caller != token.minting_account.owner) {
            return #err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Only the minting_account can mint tokens.";
                },
            );
        };

        let transfer_args : T.TransferArgs = {
            args with from_subaccount = token.minting_account.subaccount;
            fee = null;
        };

        await transfer(token, transfer_args, caller);
    };

    /// Helper function to burn tokens with minimum args
    public func burn(token : TokenData, args : BurnArgs, caller : Principal) : async Result.Result<Balance, TransferError> {

        let transfer_args : T.TransferArgs = {
            args with to = token.minting_account;
            fee = null;
        };

        await transfer(token, transfer_args, caller);
    };

    /// Returns the total number of transactions that have been processed by the given token.
    public func total_transactions(token : TokenData) : Nat {
        SB.size(token.transactions) + ArchiveApi.total_txs(token.archives);
    };

    /// Retrieves the transaction specified by the given `tx_index`
    public func get_transaction(token : TokenData, tx_index : ICRC1.TxIndex) : async ?ICRC1.Transaction {
        let archived_txs = ArchiveApi.total_txs(token.archives);
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

    // Retrieves the transactions in the request range that are in the archived
    // canister and in the main token's canister
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
            let archived_txs = ArchiveApi.total_txs(token.archives);

            // get local transactions
            let local_txs = SB.toIterFromSlice(token.transactions, 0, expected_size - txs_size);

            txs_iter := Itertools.chain(txs_iter, local_txs);
        };

        Iter.toArray(txs_iter);
    };

    /// Retrieves the transactions specified by the given range
    public func get_transactions(token : TokenData, req : ICRC1.GetTransactionsRequest) : async ICRC1.GetTransactionsResponse {
        let { archives } = token;

        let txs = await get_txs(token, req);

        let valid_range = {
            start = req.start + txs.size();
            end = Nat.min(req.start + txs.size() + req.length, total_transactions(token));
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

    // Updates the token's data and manages the transactions
    //
    // **should be added at the end of every update function**
    func update_canister(token : TokenData) : async () {
        let txs_size = SB.size(token.transactions);

        if (txs_size >= MAX_TRANSACTIONS_IN_LEDGER) {
            await ArchiveApi.append_transactions(token);
        };
    };
};
