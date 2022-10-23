import Prim "mo:prim";

import Array "mo:base/Array";
import Deque "mo:base/Deque";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Result "mo:base/Result";

import Itertools "mo:Itertools/Iter";
import SB "mo:StableBuffer/StableBuffer";
import Types "Types";

shared ({ caller = ledger_canister_id }) actor class Archive({
    max_memory_size_bytes : Nat64;
}) : async Types.ArchiveInterface {

    stable let GB = 1024 ** 3;
    stable let MAX_MEMORY = 7 * GB;

    type Transaction = Types.Transaction;

    type TransactionStore = Deque.Deque<[Transaction]>;

    stable let BUCKET_SIZE = 1000;
    stable let MAX_TRANSACTIONS_PER_REQUEST = 5000;
    stable var filled_buckets = 0;
    stable var trailing_txs = 0;
    stable var txStore : TransactionStore = Deque.empty();

    public shared ({ caller }) func append_transactions(txs : [Transaction]) : async Result.Result<(), Text> {

        if (not (caller == ledger_canister_id)) {
            return #err("Unauthorized Access: Only the owner can access this canister");
        };

        if (Prim.rts_memory_size() >= MAX_MEMORY) {
            return #err("Memory Limit: The archive canister cannot store any more transactions");
        };

        var txs_iter = txs.vals();

        switch (Deque.popBack(txStore)) {
            case (?(store, last_bucket)) {
                if (last_bucket.size() < BUCKET_SIZE) {

                    txStore := store;

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

                    store_bucket(new_last_bucket);

                    let offset : Nat = BUCKET_SIZE - last_bucket.size();

                    txs_iter := Itertools.fromArraySlice(txs, offset, txs.size());
                };
            };
            case (_) {};
        };

        for (chunk in Itertools.chunks(txs_iter, BUCKET_SIZE)) {
            store_bucket(chunk);
        };

        #ok();
    };

    public shared query func total_transactions() : async Nat {
        total_txs();
    };

    public shared query func get_transaction(tx_index : Types.TxIndex) : async ?Transaction {
        var i = 0;

        func scan(txStore : TransactionStore) : ?Transaction {
            switch (Deque.popFront(txStore)) {
                case (?(txs, store)) {
                    if (tx_index / BUCKET_SIZE == i) {
                        let bucket_index = tx_index % BUCKET_SIZE;

                        if (bucket_index < txs.size()) {
                            return ?txs[tx_index % BUCKET_SIZE];
                        } else {
                            return null;
                        };
                    };
                    i += 1;
                    scan(store);
                };
                case (_) {
                    null;
                };
            };
        };

        if (tx_index >= total_txs()) {
            null;
        } else {
            scan(txStore);
        };
    };

    public shared query func get_transactions(req : Types.GetTransactionsRequest) : async [Transaction] {
        let { start; length } = req;

        Iter.toArray(
            Itertools.take(
                txs_slice(start, length),
                MAX_TRANSACTIONS_PER_REQUEST,
            ),
        );
    };

    public shared query func remaining_capacity() : async Nat {
        MAX_MEMORY - Prim.rts_memory_size();
    };

    func store_bucket(bucket : [Transaction]) {
        txStore := Deque.pushBack(txStore, bucket);

        if (bucket.size() == BUCKET_SIZE) {
            filled_buckets += 1;
            trailing_txs := 0;
        } else {
            trailing_txs := bucket.size();
        };
    };

    func total_txs() : Nat {
        (filled_buckets * BUCKET_SIZE) + trailing_txs;
    };

    func txs_slice(start : Nat, length : Nat) : Iter.Iter<Transaction> {
        var iter = Itertools.empty<Transaction>();

        let end = start + length;
        let start_bucket = start / BUCKET_SIZE;
        let end_bucket = end / BUCKET_SIZE;

        var bucket_index = 0;

        var store = txStore;

        while (bucket_index <= start_bucket) {
            switch (Deque.popFront(store)) {
                case (?(txs, _store)) {
                    if (bucket_index == start_bucket) {
                        iter := Itertools.fromArraySlice(txs, start % BUCKET_SIZE, Nat.min(txs.size(), end));
                    };
                    store := _store;
                };
                case (_) {
                    return iter;
                };
            };

            bucket_index += 1;
        };

        while (bucket_index < end_bucket) {
            switch (Deque.popFront(store)) {
                case (?(txs, _store)) {
                    iter := Itertools.chain(iter, txs.vals());
                    store := _store;
                };
                case (_) {
                    return iter;
                };
            };

            bucket_index += 1;
        };

        if (bucket_index == end_bucket) {
            switch (Deque.popFront(store)) {
                case (?(txs, _store)) {
                    let txs_iter = Itertools.fromArraySlice(txs, 0, end % BUCKET_SIZE);
                    iter := Itertools.chain(iter, txs_iter);
                    store := _store;
                };
                case (_) {
                    return iter;
                };
            };
        };

        iter;
    };

};
