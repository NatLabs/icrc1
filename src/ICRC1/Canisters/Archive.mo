import Prim "mo:prim";
import Option "mo:base/Option";
import Bool "mo:base/Bool";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Hash "mo:base/Hash";
import Result "mo:base/Result";

import ExperimentalCycles "mo:base/ExperimentalCycles";
import ExperimentalStableMemory "mo:base/ExperimentalStableMemory";


import Itertools "mo:itertools/Iter";
import StableTrieMap "mo:StableTrieMap";
import U "../Modules/Utils";
import ArchiveTypes "../Types/Types.Archive";
import TransactionTypes "../Types/Types.Transaction";

shared ({ caller = ledger_canister_id }) actor class Archive() : async ArchiveTypes.ArchiveInterface {

    private type GetTransactionsRequest = TransactionTypes.GetTransactionsRequest;
    private type TransactionRange = TransactionTypes.TransactionRange;
    private type TxIndex = TransactionTypes.TxIndex;
    private type Transaction = TransactionTypes.Transaction;
    private type MemoryBlock = {
        offset : Nat64;
        size : Nat;
    };

    stable let KiB = 1024;
    stable let GiB = KiB ** 3;
    stable let MEMORY_PER_PAGE : Nat64 = Nat64.fromNat(64 * KiB);
    stable let MIN_PAGES : Nat64 = 32; // 2MiB == 32 * 64KiB
    stable var PAGES_TO_GROW : Nat64 = 2048; // 64MiB
    stable let MAX_MEMORY = 32 * GiB;

    stable let BUCKET_SIZE = 1000;

    //The maximum number of transactions returned by request of 'get_transactions'
    stable let MAX_TRANSACTIONS_PER_REQUEST = 5000;

    //stable let MAX_TXS_LENGTH = 100;

    stable var memory_pages : Nat64 = ExperimentalStableMemory.size();
    stable var total_memory_used : Nat64 = 0;
    stable var total_previous_archives_count:Nat = 0;
    stable var next_archive_was_set: Bool = false;
    stable var filled_buckets = 0;
    stable var trailing_txs = 0;

    stable let txStore = StableTrieMap.new<Nat, [MemoryBlock]>();

    stable var prevArchive : ArchiveTypes.ArchiveInterface = actor ("aaaaa-aa");
    stable var nextArchive : ArchiveTypes.ArchiveInterface = actor ("aaaaa-aa");
    stable var first_tx : Nat = 0;
    stable var last_tx : Nat = 0;


    public shared query func get_prev_archive() : async ArchiveTypes.ArchiveInterface {
        prevArchive;
    };

    public shared query func get_next_archive() : async ArchiveTypes.ArchiveInterface {
        nextArchive;
    };

    public shared query func get_first_tx() : async Nat {
        first_tx;
    };

    public shared query func get_last_tx() : async Nat {
        last_tx;
    };

    
    public shared query func get_previous_archive_count() : async Nat {
                  
         return total_previous_archives_count;      
    };

    public shared ({ caller }) func set_previous_archive_count(count : Nat) : async Result.Result<(), Text> {

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        
        //Can only be set one time:
        if (next_archive_was_set == false){
            total_previous_archives_count:=count;
            next_archive_was_set:=true;
        };

        #ok();
    };

    public shared ({ caller }) func set_prev_archive(prev_archive : ArchiveTypes.ArchiveInterface) : async Result.Result<(), Text> {

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        prevArchive := prev_archive;

        #ok();
    };

    public shared ({ caller }) func set_next_archive(next_archive : ArchiveTypes.ArchiveInterface) : async Result.Result<(), Text> {

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        ignore await next_archive.set_previous_archive_count(total_previous_archives_count + 1);
        
        nextArchive := next_archive;


        #ok();
    };

    public shared ({ caller }) func set_first_tx(tx : Nat) : async Result.Result<(), Text> {

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        first_tx := tx;

        #ok();
    };

    public shared ({ caller }) func set_last_tx(tx : Nat) : async Result.Result<(), Text> {

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        last_tx := tx;

        #ok();
    };

    public shared ({ caller }) func append_transactions(txs : [Transaction]) : async Result.Result<(), Text> {

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        var txs_iter = txs.vals();

        if (BucketIsNotEmpty()) {
            let last_bucket = StableTrieMap.get(
                txStore,
                Nat.equal,
                U.hash,
                filled_buckets,
            );

            switch (last_bucket) {
                case (?last_bucket) {
                    let new_bucket = Iter.toArray(
                        Itertools.take(
                            Itertools.chain(
                                last_bucket.vals(),
                                Iter.map(txs.vals(), store_tx),
                            ),
                            BUCKET_SIZE,
                        ),
                    );

                    if (new_bucket.size() == BUCKET_SIZE) {
                        let offset = (BUCKET_SIZE - last_bucket.size()) : Nat;

                        txs_iter := Itertools.fromArraySlice(txs, offset, txs.size());
                    } else {
                        txs_iter := Itertools.empty();
                    };

                    store_bucket(new_bucket);
                };
                case (_) {};
            };
        };

        for (chunk in Itertools.chunks(txs_iter, BUCKET_SIZE)) {
            store_bucket(Array.map(chunk, store_tx));
        };

        #ok();
    };

    func total_txs() : Nat {
        (filled_buckets * BUCKET_SIZE) + trailing_txs;
    };

    public shared query func total_transactions() : async Nat {
        total_txs();
    };

    public shared query func get_transaction(tx_index : TxIndex) : async ?Transaction {
        
        //Absolute index ==> global transaction index
        let tx_absolute_index = Nat.max(tx_index, first_tx);

        //Relative index ==> internal index for this specific archive canister (We can have more than one archive canister) 
        let tx_relative_index : Nat = tx_absolute_index - first_tx;

        let bucket_key = tx_relative_index / BUCKET_SIZE;
        
        let opt_bucket = StableTrieMap.get(
            txStore,
            Nat.equal,
            U.hash,
            bucket_key,
        );

        switch (opt_bucket) {
            case (?bucket) {
                let i = tx_relative_index % BUCKET_SIZE;
                if (i < bucket.size()) {
                    ?get_tx(bucket[tx_relative_index % BUCKET_SIZE]);
                } else {
                    null;
                };
            };
            case (_) {
                null;
            };
        };
    };

    public shared query func get_transactions(req : GetTransactionsRequest) : async TransactionRange {
        let { start; length } = req;
        var iter = Itertools.empty<MemoryBlock>();
           
        let numberOfTransactionsToReturn = Nat.min(Nat.max(0, length), MAX_TRANSACTIONS_PER_REQUEST);
        let startTransactionNumber:Nat = Nat.max(start, first_tx);
        let startTransactionRelativeIndex:Nat = startTransactionNumber - first_tx;
        let start_bucket_index:Nat = startTransactionRelativeIndex / BUCKET_SIZE;        
        let end_bucket_index:Nat = (startTransactionRelativeIndex + numberOfTransactionsToReturn) / BUCKET_SIZE;
        var transactionsLeft = numberOfTransactionsToReturn;
             
        label _loop for (i in Itertools.range(start_bucket_index, end_bucket_index + 1)) {
            let opt_bucket = StableTrieMap.get(
                txStore,
                Nat.equal,
                U.hash,
                i,
            );
           
            switch (opt_bucket) {
                case (?bucket) {
                    if (i == start_bucket_index) {                        
                        let indexInBucket:Nat = startTransactionRelativeIndex % BUCKET_SIZE;                         
                        let numberOfIndizesToUse:Nat = Nat.min(bucket.size()-indexInBucket,numberOfTransactionsToReturn);                          
                        iter := Itertools.fromArraySlice(bucket, indexInBucket, indexInBucket + numberOfIndizesToUse);   
                        transactionsLeft:=transactionsLeft - numberOfIndizesToUse;                        
                    } else if (i == end_bucket_index) {
                        
                        let numberOfIndizesToUse:Nat = Nat.min(bucket.size(),transactionsLeft);                             
                        let bucket_iter = Itertools.fromArraySlice(bucket, 0, numberOfIndizesToUse);                        
                        iter := Itertools.chain(iter, bucket_iter);
                        transactionsLeft:=transactionsLeft - numberOfIndizesToUse;
                    } else {                                                
                        
                        iter := Itertools.chain(iter, bucket.vals());
                        transactionsLeft:=transactionsLeft - bucket.size();
                    };
                };
                case (_) {                                
                    break _loop };
            };
        };
        
        let transactions = Iter.toArray(
            Iter.map(                
                Itertools.take(iter, numberOfTransactionsToReturn),
                get_tx,
            ),
        );
        
        { transactions };
    };

    public shared query func remaining_capacity() : async Nat {
        MAX_MEMORY - Nat64.toNat(total_memory_used);
    };

    public shared query func max_memory() : async Nat {
        MAX_MEMORY;
    };

    public shared query func total_used() : async Nat {
        Nat64.toNat(total_memory_used);
    };

    /// Deposit cycles into this archive canister.
    public shared func deposit_cycles() : async () {
        let amount = ExperimentalCycles.available();
        let accepted = ExperimentalCycles.accept(amount);
        assert (accepted == amount);
    };

    func to_blob(tx : Transaction) : Blob {
        to_candid (tx);
    };

    func from_blob(tx : Blob) : Transaction {
        switch (from_candid (tx) : ?Transaction) {
            case (?tx) tx;
            case (_) Debug.trap("Could not decode tx blob");
        };
    };

    func store_tx(tx : Transaction) : MemoryBlock {
        let blob = to_blob(tx);

        if ((memory_pages * MEMORY_PER_PAGE) - total_memory_used < (MIN_PAGES * MEMORY_PER_PAGE)) {
            ignore ExperimentalStableMemory.grow(PAGES_TO_GROW);
            memory_pages += PAGES_TO_GROW;
        };

        let offset = total_memory_used;

        ExperimentalStableMemory.storeBlob(
            offset,
            blob,
        );

        let mem_block = {
            offset;
            size = blob.size();
        };

        total_memory_used += Nat64.fromNat(blob.size());
        mem_block;
    };

    func get_tx({ offset; size } : MemoryBlock) : Transaction {
        let blob = ExperimentalStableMemory.loadBlob(offset, size);

        let tx = from_blob(blob);
    };

    func store_bucket(bucket : [MemoryBlock]) {

        StableTrieMap.put(
            txStore,
            Nat.equal,
            U.hash,
            filled_buckets,
            bucket,
        );

        if (bucket.size() == BUCKET_SIZE) {
            filled_buckets += 1;
            trailing_txs := 0;
        } else {
            trailing_txs := bucket.size();
        };
    };


    //Helper functions:
    private func BucketIsNotEmpty():Bool{
        trailing_txs > 0;
    }
};
