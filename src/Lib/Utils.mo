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
    // Creates a Stable Buffer with the default metadata and returns it.
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

    // Creates a Stable Buffer with the default supported standards and returns it.
    public func init_standards() : StableBuffer.StableBuffer<T.SupportedStandard> {
        let standards = SB.initPresized<T.SupportedStandard>(4);
        SB.add(standards, default_standard);

        standards;
    };

    // Returns the default subaccount for cases where a user does
    // not specify it.
    public func default_subaccount() : T.Subaccount {
        Blob.fromArray(
            Array.tabulate(32, func(_ : Nat) : Nat8 { 0 }),
        );
    };

    // Creates a new triemap for storing users subaccounts and balances
    public func new_subaccount_map(
        subaccount : ?T.Subaccount,
        balance : T.Balance,
    ) : T.SubaccountStore {
        let map : T.SubaccountStore = STMap.new();

        STMap.put(
            map,
            Blob.equal,
            Blob.hash,
            Option.get(subaccount, default_subaccount()),
            balance,
        );

        map;
    };

    // Retrieves the balance of an account
    public func get_balance(accounts : T.AccountStore, req : T.Account) : T.Balance {
        switch (STMap.get(accounts, Principal.equal, Principal.hash, req.owner)) {
            case (?subaccounts) {
                switch (req.subaccount) {
                    case (?sub) {
                        switch (STMap.get(subaccounts, Blob.equal, Blob.hash, sub)) {
                            case (?balance) {
                                balance;
                            };
                            case (_) 0;
                        };
                    };
                    case (_) {
                        switch (STMap.get(subaccounts, Blob.equal, Blob.hash, default_subaccount())) {
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

    // Updates the balance of an account
    public func update_balance(
        accounts : T.AccountStore,
        req : T.Account,
        update : (T.Balance) -> T.Balance,
    ) {

        let subaccount = switch (req.subaccount) {
            case (?sub) sub;
            case (_) default_subaccount();
        };

        switch (STMap.get(accounts, Principal.equal, Principal.hash, req.owner)) {
            case (?subaccounts) {
                switch (STMap.get(subaccounts, Blob.equal, Blob.hash, subaccount)) {
                    case (?balance) {
                        STMap.put(subaccounts, Blob.equal, Blob.hash, subaccount, update(balance));
                    };
                    case (_) {
                        STMap.put(subaccounts, Blob.equal, Blob.hash, subaccount, update(0));
                    };
                };
            };
            case (_) {
                STMap.put(
                    accounts,
                    Principal.equal,
                    Principal.hash,
                    req.owner,
                    new_subaccount_map(?subaccount, update(0)),
                );
            };
        };
    };

    // Checks if there is a duplicate of the given transaction
    // stored in the main canister
    public func tx_has_duplicates(token : T.TokenData, tx_req : T.TransactionRequest) : Result.Result<(), Nat> {
        let { transactions = txs } = token;

        var phantom_txs_size = 0;
        let phantom_txs = SB._clearedElemsToIter(txs);
        let current_txs = SB.toIter(txs);

        let archived_txs = total_archived_txs(token.archives);

        let last_2000_txs = if (archived_txs > 0) {
            phantom_txs_size := SB.capacity(txs) - SB.size(txs);
            Itertools.chain(phantom_txs, current_txs);
        } else {
            current_txs;
        };

        for ((i, tx) in Itertools.enumerate(last_2000_txs)) {
            let res = switch (tx_req.kind) {
                case (#mint) {
                    switch (tx.mint) {
                        case (?mint) {
                            let mint_req : T.Mint = tx_req;

                            mint_req == mint;
                        };
                        case (_) false;
                    };
                };
                case (#burn) {
                    switch (tx.burn) {
                        case (?burn) {
                            let burn_req : T.Burn = tx_req;

                            burn_req == burn;
                        };
                        case (_) false;
                    };
                };
                case (#transfer) {
                    switch (tx.transfer) {
                        case (?transfer) {
                            let transfer_req : T.Transfer = tx_req;

                            transfer_req == transfer;
                        };
                        case (_) false;
                    };
                };

            };

            if (res) {
                let index = return #err(archived_txs + i - phantom_txs_size);
            };
        };

        #ok();
    };

    // Formats the different operation arguements into
    // a `TransactionRequest`, an internal type to access fields easier.
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

    // Transforms the transaction kind from `variant` to `Text`
    public func kind_to_text(kind : T.OperationKind) : Text {
        switch (kind) {
            case (#mint) "MINT";
            case (#burn) "BURN";
            case (#transfer) "TRANSFER";
        };
    };

    // Formats the tx request into a finalised transaction
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

    // Transfers tokens from the sender to the
    // recipient based on the given tx request
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

    // Transfers tokens based on the tx request
    // and stores the transaction
    public func process_tx(token : T.TokenData, tx_req : T.TransactionRequest) : T.Transaction {
        transfer(token.accounts, tx_req);

        let tx = req_to_tx(tx_req);
        SB.add(token.transactions, tx);

        tx;
    };

    // Get the number of all archived transactions
    public func total_archived_txs(archives : T.StableBuffer<T.ArchiveData>) : Nat {
        var total = 0;

        for ({ length } in SB.toIter(archives)) {
            total += length;
        };

        total;
    };

    // Stable Buffer Module with some additional functions
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

        _clearedElemsToIter = func<A>(buffer : T.StableBuffer<A>) : Iter.Iter<A> {
            Iter.map(
                Itertools.range(buffer.count, buffer.elems.size()),
                func(i : Nat) : A {
                    buffer.elems[i];
                },
            );
        };
    };
};
