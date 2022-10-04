import Array "mo:base/Array";
import Deque "mo:base/Deque";
import Nat "mo:base/Nat";
import Result "mo:base/Result";

import ICRC1 "Types";

shared({ caller = ledger_canister_id }) actor class ArchiveCanister({
    max_memory_size_bytes : Nat64;
}) : async ICRC1.ArchiveInterface {

    let DEFAULT_MAX_MEMORY_SIZE = 1024 * 1024 * 1024;

    type Transaction = ICRC1.Transaction;

    type TransactionStore = Deque.Deque<[Transaction]>;

    stable var txStore : TransactionStore = Deque.empty();

    public shared({ caller }) func append_transactions(txs : [Transaction]) : async Result.Result<(), ()> {
        if (caller == ledger_canister_id) {
            txStore := Deque.pushBack(txStore, txs);

            #ok();
        } else {
            #err();
        };
    };

    public shared query func get_transaction(tx_index : ICRC1.TxIndex) : async ?Transaction {
        var i = 0;

        func scan(txStore : TransactionStore) : ?Transaction {
            switch (Deque.popFront(txStore)) {
                case (?(txs, store)) {
                    if (tx_index / 1000 == i) {
                        return ?txs[tx_index % 1000];
                    };
                    i += 1;
                    scan(store);
                };
                case (_) {
                    null;
                };
            };
        };

        scan(txStore);
    };

    public shared query func get_transactions(req : ICRC1.GetTransactionsRequest) : async [ICRC1.Transaction] {
        let { start; length } = req;
        var store_index = 0;
        var store = txStore;

        func scan(txStore : TransactionStore) : [Transaction] {
            switch (Deque.popFront(txStore)) {
                case (?(txs, _store)) {
                    if (start / 1000 == store_index) {
                        let array_index = store_index % 1000;

                        return Array.tabulate(
                            Nat.min(length, 1000 - array_index),
                            func(i : Nat) : Transaction {
                                txs[array_index + i];
                            },
                        );
                    };
                    store_index += 1;
                    store := _store;

                    scan(store);
                };
                case (_) {
                    [];
                };
            };
        };

        let transactions = scan(store);

        transactions;
    };

    public shared query func remaining_capacity() : async Nat64 {
        2;
    };
};
