import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";

import Itertools "mo:Itertools/Iter";
import StableBuffer "mo:StableBuffer/StableBuffer";
import STMap "mo:StableTrieMap";

import T "Types";

module {
    public func init_metadata(args : T.InitArgs) : StableBuffer.StableBuffer<T.MetaDatum> {
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

    public func init_standards() : StableBuffer.StableBuffer<T.SupportedStandard> {
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

    public func validate_transfer(
        token : T.TokenData,
        tx_req : T.TransactionRequest,
    ) : Result.Result<(), T.TransferError> {

        if (tx_req.from == tx_req.to) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "The from cannot have the same account as the to.";
                }),
            );
        };

        if (not validate_account(tx_req.from)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for from.";
                }),
            );
        };

        if (not validate_account(tx_req.to)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for to";
                }),
            );
        };

        if (not validate_memo(tx_req.memo)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Memo must not be more than 32 bytes";
                }),
            );
        };

        switch (validate_transaction_time(token.transaction_window, tx_req.created_at_time)) {
            case (#err(errorMsg)) {
                return #err(errorMsg);
            };
            case (_) {};
        };

        let sender_balance : T.Balance = get_balance(
            token.accounts,
            tx_req.from,
        );

        if (tx_req.amount > sender_balance) {
            return #err(#InsufficientFunds { balance = sender_balance });
        };

        #ok();
    };

    public func args_to_req(operation : T.Operation, minting_account : T.Account) : T.TransactionRequest {
        switch (operation) {
            case (#mint(args)) {
                {
                    args with kind = #mint;
                    from = minting_account;
                    fee = null;
                };
            };
            case (#burn(args)) {
                {
                    args with kind = #burn;
                    to = minting_account;
                    fee = null;
                };
            };
            case (#transfer(args)) {
                {
                    args with kind = #transfer;
                };
            };
        };
    };

    public func kind_to_text(kind : T.OperationKind) : Text {
        switch (kind) {
            case (#mint) "MINT";
            case (#burn) "BURN";
            case (#transfer) "TRANSFER";
        };
    };

    public func req_to_tx(tx_req : T.TransactionRequest) : T.Transaction {

        {
            kind = kind_to_text(tx_req.kind);
            mint = switch (tx_req.kind) {
                case (#mint) { ?tx_req };
                case (_) null;
            };

            burn = switch (tx_req.kind) {
                case (#burn) { ?tx_req };
                case (_) null;
            };

            transfer = switch (tx_req.kind) {
                case (#transfer) { ?tx_req };
                case (_) null;
            };

            timestamp = Nat64.fromNat(Int.abs(Time.now()));
        };
    };

    public func transfer(
        accounts : T.AccountStore,
        tx_req : T.TransactionRequest,
    ) {
        let { from; to; amount } = tx_req;

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

    public func store_tx(
        txs : StableBuffer.StableBuffer<T.Transaction>,
        tx : T.Transaction,
    ) {
        SB.add(txs, tx);
    };

    public func process_tx(token : T.TokenData, tx_req : T.TransactionRequest) : T.Transaction {
        transfer(token.accounts, tx_req);

        let tx = req_to_tx(tx_req);
        store_tx(token.transactions, tx);

        tx;
    };

    public func total_archived_txs(archives : T.StableBuffer<T.ArchiveData>) : Nat {
        var total = 0;

        for ({ length } in SB.toIter(archives)) {
            total += length;
        };

        total;
    };

    public func debug_token(token : T.TokenData) {
        Debug.print("Name: " # token.name);
        Debug.print("Symbol: " # token.symbol);
        Debug.print("Decimals: " # debug_show token.decimals);
        Debug.print("Fee: " # debug_show token.fee);
        Debug.print("transaction_window: " # debug_show token.transaction_window);
        Debug.print("minting_account: " # debug_show token.minting_account);
        Debug.print("metadata: " # debug_show token.metadata);
        Debug.print("supported_standards: " # debug_show token.supported_standards);
        // Debug.print("accounts: " # debug_show
        //     Iter.toArray(
        //         Iter.map(
        //             STMap.entries(token.accounts),
        //             func((k, v) : (Principal, STMap.StableTrieMap<Blob, Nat>)) : (Principal, [(Blob, Nat)]) {
        //                 (k, Iter.toArray(STMap.entries(v)))
        //             }
        //         )
        //     )
        // );
        Debug.print("transactions: " # debug_show SB.size(token.transactions));
        Debug.print(
            "transactions: " # debug_show Array.tabulate(
                SB.size(token.transactions),
                func(i : Nat) : T.Transaction {
                    SB.get(token.transactions, i);
                },
            ),
        );
    };

    public module Validate = {
        public let transaction_time = validate_transaction_time;
        public let memo = validate_memo;
        public let account = validate_account;
        public let subaccount = validate_subaccount;
        public let transfer = validate_transfer;
    };

    public let SB = {
        StableBuffer with toIter = func<A>(buffer : T.StableBuffer<A>) : Iter.Iter<A> {
            SB.toIterFromSlice(buffer, 0, SB.size(buffer));
        };

        toIterFromSlice = func<A>(buffer : T.StableBuffer<A>, start : Nat, end : Nat) : Iter.Iter<A> {
            if (start >= SB.size(buffer)) {
                return Itertools.empty();
            };

            Iter.map(
                Itertools.range(start, Nat.min(SB.size(buffer), end)),
                func(i : Nat) : A {
                    SB.get(buffer, i);
                },
            );
        };

        appendArray = func<A>(buffer : T.StableBuffer<A>, array : [A]) {
            for (elem in array.vals()) {
                SB.add(buffer, elem);
            };
        };

        getLast = func<A>(buffer : T.StableBuffer<A>) : ?A {
            let size = SB.size(buffer);

            if (size > 0) {
                SB.getOpt(buffer, (size - 1) : Nat);
            } else {
                null;
            };
        };

        capacity = func<A>(buffer : T.StableBuffer<A>) : Nat {
            buffer.elems.size();
        };
    };
};
