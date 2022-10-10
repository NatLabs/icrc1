import Array "mo:base/Array";
import Deque "mo:base/Deque";
import Nat "mo:base/Nat";
import Result "mo:base/Result";

import ArrayModule "mo:array/Array";
import Itertools "mo:Itertools/Iter";
import ICRC1 "Types";

shared ({ caller = ledger_canister_id }) actor class ArchiveCanister({
    max_memory_size_bytes : Nat64;
}) : async ICRC1.ArchiveInterface {

    let DEFAULT_MAX_MEMORY_SIZE = 1024 * 1024 * 1024;

    type Transaction = ICRC1.Transaction;

    type TransactionStore = Deque.Deque<[Transaction]>;

    let BUCKET_SIZE = 1000;
    stable var buckets = 0;
    stable var txs = 0;
    stable var txStore : TransactionStore = Deque.empty();

    public shared ({ caller }) func append_transactions(txs : [Transaction]) : async Result.Result<(), Text> {
        if (caller == ledger_canister_id) {
            var txs_iter = txs.vals();

            switch (Deque.popBack(txStore)) {
                case (?(store, last_bucket)) {
                    if (last_bucket.size() < BUCKET_SIZE) {

                        let new_last_bucket = Array.tabulate(
                            Nat.min(
                                BUCKET_SIZE,
                                last_bucket.size() + txs.size(),
                            ),
                            func(i : Nat) : Transaction {
                                if (i < last_bucket.size()) {
                                    last_bucket[i];
                                } else {
                                    txs[i - last_bucket.size()];
                                };
                            },
                        );

                        txStore := Deque.pushBack(store, new_last_bucket);

                        let offset = BUCKET_SIZE - last_bucket.size();

                        txs_iter := Itertools.fromArraySlice(txs, offset, txs.size());
                    };
                };
                case (_) {};
            };

            for (chunk in Itertools.chunks(txs_iter, BUCKET_SIZE)) {
                txStore := Deque.pushBack(txStore, chunk);
                buckets += 1;
            };

            #ok();

        } else {
            #err("Unauthorized Access: Only the owner can access this canister");
        };
    };

    public shared query func get_transaction(tx_index : ICRC1.TxIndex) : async ?Transaction {
        var i = 0;

        func scan(txStore : TransactionStore) : ?Transaction {
            switch (Deque.popFront(txStore)) {
                case (?(txs, store)) {
                    if (tx_index / BUCKET_SIZE == i) {
                        return ?txs[tx_index % BUCKET_SIZE];
                    };
                    i += 1;
                    scan(store);
                };
                case (_) {
                    null;
                };
            };
        };

        if (tx_index > (buckets * BUCKET_SIZE)) {
            null;
        } else {
            scan(txStore);
        };
    };

    public shared query func get_transactions(req : ICRC1.GetTransactionsRequest) : async [ICRC1.Transaction] {
        let { start; length } = req;
        var store_index = 0;
        var store = txStore;

        func scan(txStore : TransactionStore) : [Transaction] {
            switch (Deque.popFront(txStore)) {
                case (?(txs, _store)) {
                    if (start / BUCKET_SIZE == store_index) {
                        let array_index = store_index % BUCKET_SIZE;

                        return Array.tabulate(
                            Nat.min(length, BUCKET_SIZE - array_index),
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
