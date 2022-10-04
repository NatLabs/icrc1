import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";

import SB "mo:StableBuffer/StableBuffer";
import STMap "mo:StableTrieMap";

import T "Types";

module {
    public func init_metadata(args : T.InitArgs) : SB.StableBuffer<T.MetaDatum> {
        let metadata = SB.initPresized<T.MetaDatum>(4);
        SB.add(metadata, ("icrc1:fee", #Nat(args.fee)));
        SB.add(metadata, ("icrc1:name", #Text(args.name)));
        SB.add(metadata, ("icrc1:symbol", #Text(args.symbol)));
        SB.add(metadata, ("icrc1:decimals", #Nat(Nat8.toNat(args.decimals))));

        metadata;
    };

    public let default_standard : T.SupportedStandard = {
        name = "ICRC-1";
        url = "https://github.com/dfinity/ICRC-1";
    };

    public let DAY_IN_NANO_SECONDS : T.Timestamp = 86_400_000_000_000;

    public func init_standards() : SB.StableBuffer<T.SupportedStandard> {
        let standards = SB.initPresized<T.SupportedStandard>(4);
        SB.add(standards, default_standard);

        standards;
    };

    public func validate_subaccount(subaccount : ?T.Subaccount) : Bool {
        switch (subaccount) {
            case (?bytes) {
                bytes.size() == 32;
            };
            case (_) true;
        };
    };

    public func validate_account(account : T.Account) : Bool {
        if (Principal.isAnonymous(account.owner)) {
            false;
        } else if (not validate_subaccount(account.subaccount)) {
            false;
        } else {
            true;
        };
    };

    public func validate_memo(memo : ?T.Memo) : Bool {
        switch (memo) {
            case (?bytes) {
                bytes.size() <= 32;
            };
            case (_) true;
        };
    };

    public func validate_transaction_time(
        transaction_window : T.Timestamp,
        _created_at_time : ?T.Timestamp,
    ) : Result.Result<(), T.TimeError> {
        let now = Time.now();
        let created_at_time = switch (_created_at_time) {
            case (?time_in_nat64) {
                Nat64.toNat(time_in_nat64) : Int;
            };
            case (_) now;
        };

        let diff = now - created_at_time;

        if (created_at_time > now) {
            return #err(
                #CreatedInFuture {
                    ledger_time = Nat64.fromNat(Int.abs(now));
                },
            );
        } else if (diff > (Nat64.toNat(transaction_window) : Int)) {
            return #err(#TooOld);
        };

        #ok();
    };

    public func default_subaccount() : T.Subaccount {
        Blob.fromArray(
            Array.tabulate(32, func(_ : Nat) : Nat8 { 0 }),
        );
    };

    public func new_subaccount_map(
        subaccount : ?T.Subaccount,
        balance : T.Balance,
    ) : T.SubaccountStore {
        let map : T.SubaccountStore = STMap.new(Blob.equal, Blob.hash);

        STMap.put(
            map,
            Option.get(subaccount, default_subaccount()),
            balance,
        );

        map;
    };

    public func get_balance(accounts : T.AccountStore, req : T.Account) : T.Balance {
        switch (STMap.get(accounts, req.owner)) {
            case (?subaccounts) {
                switch (req.subaccount) {
                    case (?sub) {
                        switch (STMap.get(subaccounts, sub)) {
                            case (?balance) {
                                balance;
                            };
                            case (_) 0;
                        };
                    };
                    case (_) {
                        switch (STMap.get(subaccounts, default_subaccount())) {
                            case (?balance) {
                                balance;
                            };
                            case (_) 0;
                        };
                    };
                };
            };
            case (_) 0;
        };
    };

    public func update_balance(
        accounts : T.AccountStore,
        req : T.Account,
        update : (T.Balance) -> T.Balance,
    ) {

        let subaccount = switch (req.subaccount) {
            case (?sub) sub;
            case (_) default_subaccount();
        };

        switch (STMap.get(accounts, req.owner)) {
            case (?subaccounts) {
                switch (STMap.get(subaccounts, subaccount)) {
                    case (?balance) {
                        STMap.put(subaccounts, subaccount, update(balance));
                    };
                    case (_) {
                        STMap.put(subaccounts, subaccount, update(0));
                    };
                };
            };
            case (_) {
                STMap.put(
                    accounts,
                    req.owner,
                    new_subaccount_map(?subaccount, update(0)),
                );
            };
        };
    };

    public func transfer_args_to_internal(
        args : T.TransferArgs,
        caller : Principal,
    ) : T.InternalTransferArgs {
        {
            from = {
                owner = caller;
                subaccount = args.from_subaccount;
            };
            to = args.to;
            amount = args.amount;
            fee = args.fee;
            memo = args.memo;
            created_at_time = args.created_at_time;
        };
    };

    public func validate_transfer(
        token : T.InternalData,
        args : T.InternalTransferArgs,
    ) : Result.Result<(), T.TransferError> {

        if (args.from == args.to) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "The from cannot have the same account as the to.";
                }),
            );
        };

        if (not validate_account(args.from)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for from.";
                }),
            );
        };

        if (not validate_account(args.to)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for to";
                }),
            );
        };

        if (not validate_memo(args.memo)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Memo must not be more than 32 bytes";
                }),
            );
        };

        switch (validate_transaction_time(token.transaction_window, args.created_at_time)) {
            case (#err(errorMsg)) {
                return #err(errorMsg);
            };
            case (_) {};
        };

        let sender_balance : T.Balance = get_balance(
            token.accounts,
            args.from,
        );

        if (args.amount > sender_balance) {
            return #err(#InsufficientFunds { balance = sender_balance });
        };

        #ok();
    };

    public func args_to_tx(args : T.InternalTransferArgs, tx_kind : T.TxKind) : T.Transaction {
        {
            kind = tx_kind;
            from = args.from;
            to = args.to;
            amount = args.amount;
            memo = Option.get(args.memo, Blob.fromArray([]));
            fee = Option.get(args.fee, 0);
            time = Nat64.fromNat(Int.abs(Time.now()));
        };
    };

    public func store_tx(
        token : T.InternalData,
        args : T.InternalTransferArgs,
        tx_kind : T.TxKind,
    ) {
        let tx = args_to_tx(args, tx_kind);
        SB.add(token.transactions, tx);
    };

    public func transfer(
        accounts : T.AccountStore,
        args : T.InternalTransferArgs,
    ) {
        let { from; to; amount } = args;

        update_balance(
            accounts,
            from,
            func(balance) {
                balance - amount;
            },
        );

        update_balance(
            accounts,
            to,
            func(balance) {
                balance + amount;
            },
        );
    };

    public func debug_token(token : T.InternalData) {
        Debug.print("Name: " # token.name);
        Debug.print("Symbol: " # token.symbol);
        Debug.print("Decimals: " # debug_show token.decimals);
        Debug.print("Fee: " # debug_show token.fee);
        Debug.print("transaction_window: " # debug_show token.transaction_window);
        Debug.print("minting_account: " # debug_show token.minting_account);
        Debug.print("metadata: " # debug_show token.metadata);
        Debug.print("supported_standards: " # debug_show token.supported_standards);
        // Debug.print("accounts: " # debug_show token.accounts);
        Debug.print("transactions: " # debug_show token.transactions);
    };
};
