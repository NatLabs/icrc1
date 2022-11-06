import Archive "Canisters/Archive";
import T "Types";

import { SB } "Utils";

module {
    /// creates a new archive canister
    public func create_canister() : async T.ArchiveInterface {
        await Archive.Archive();
    };

    /// Get the total number of archived transactions
    public func total_txs(archives : T.StableBuffer<T.ArchiveData>) : Nat {
        var total = 0;

        for ({ length } in SB.vals(archives)) {
            total += length;
        };

        total;
    };

    // Retrieves the last archive in the archives buffer
    func get_last_archive(token : T.TokenData) : ?T.ArchiveData {
        SB.getLast(token.archives);
    };

    // Adds a new archive canister to the archives array
    func add_canister(token : T.TokenData) : async () {

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
            canister = await create_canister();
        };

        SB.add(token.archives, new_archive);
    };

    // Updates the last archive in the archives buffer
    func update_last_archive(token : T.TokenData, update : (T.ArchiveData) -> async T.ArchiveData) : async () {
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

    func _append_transactions(token : T.TokenData) : async Bool {
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

    /// Moves the transactions from the ICRC1 canister to the archive canister
    /// and returns a boolean that indicates the success of the data transfer
    public func append_transactions(token : T.TokenData) : async () {
        let { archives } = token;

        if (SB.size(archives) == 0) {
            await add_canister(token);
        };

        if (not (await _append_transactions(token))) {
            await add_canister(token);
            ignore (await _append_transactions(token));
        };
    };

};
