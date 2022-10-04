import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Result "mo:base/Result";

import SB "mo:StableBuffer/StableBuffer";

import ICRC1 "Lib/ICRC1";
import ArchiveCanister "Lib/ArchiveCanister";

shared({ caller = _owner }) actor class Token(
    _name : Text,
    _symbol : Text,
    _decimals : Nat8,
    _fee : ICRC1.Balance,
    _max_supply : ICRC1.Balance,
    _minting_account : ?ICRC1.Account,
    _initial_balances : ?[(Principal, [(ICRC1.Subaccount, ICRC1.Balance)])],
) : async ICRC1.Interface {

    let token = ICRC1.init({
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        fee = _fee;
        max_supply = _max_supply;
        minting_account = Option.get(
            _minting_account,
            {
                owner = _owner;
                subaccount = null;
            },
        );
        initial_balances = Option.get(_initial_balances, []);
    });

    var archive : ICRC1.ArchiveInterface = actor ("aaaaa-a");
    var archived_transactions = 0;

    func create_archive() : async () {
        if (SB.size(token.transactions) == 0 and archived_transactions == 0) {
            archive := await ArchiveCanister.ArchiveCanister({
                max_memory_size_bytes = ICRC1.MAX_TRANSACTION_BYTES;
            });
        };
    };

    public shared func get_transaction(tx_index : ICRC1.TxIndex) : async ?ICRC1.Transaction {
        if (tx_index < archived_transactions) {
            await archive.get_transaction(tx_index);
        } else {
            ICRC1.get_transaction(token, tx_index - archived_transactions);
        };
    };

    func _get_transactions(req : ICRC1.GetTransactionsRequest) : async [ICRC1.Transaction] {
        let txs = if (req.start < archived_transactions) {
            await archive.get_transactions(req);
        } else {
            ICRC1.get_transactions(token, req);
        };
    };

    public shared func get_transactions(req : ICRC1.GetTransactionsRequest) : async ICRC1.GetTransactionsResponse {

        let txs = [];
        let { start; length } = req;
        let end = start + length;

        let total_txs = archived_transactions + SB.size(token.transactions);

        let archived = if (txs.size() > 0 and end < archived_transactions) {

            let n = ((total_txs - end) / ICRC1.MAX_TRANSACTIONS_IN_LEDGER) + 1;

            let buffer = SB.initPresized<ICRC1.ArchivedTransaction>(n);

            for (i in Iter.range(1, n)) {
                SB.add<ICRC1.ArchivedTransaction>(
                    buffer,
                    {
                        start = start + (i * ICRC1.MAX_TRANSACTIONS_IN_LEDGER);
                        length = ICRC1.MAX_TRANSACTIONS_IN_LEDGER;
                    },
                );
            };

            SB.toArray(buffer)

        } else {
            [];
        };

        {
            log_length = total_txs;
            transactions = txs;

            first_index = if (txs.size() > 0) { ?start } else { null };

            archived_transactions = archived;
        };
    };

    func archive_capacity() : async Nat64 {
        await archive.remaining_capacity();
    };

    func append_transactions(txs : [ICRC1.Transaction]) : async Result.Result<(), ()> {
        await archive.append_transactions(txs);
    };

    // should be added at the end of every update call
    func update_canister() : async () {
        if (SB.size(token.transactions) == ICRC1.MAX_TRANSACTIONS_IN_LEDGER) {
            if (archived_transactions == 0) {
                await create_archive();
            };

            let res = await append_transactions(SB.toArray(token.transactions));

            SB.clear(token.transactions);
        };
    };

    /// Functions for the ICRC1 token standard
    public shared query func icrc1_name() : async Text {
        ICRC1.name(token);
    };

    public shared query func icrc1_symbol() : async Text {
        ICRC1.symbol(token);
    };

    public shared query func icrc1_decimals() : async Nat8 {
        ICRC1.decimals(token);
    };

    public shared query func icrc1_fee() : async ICRC1.Balance {
        ICRC1.fee(token);
    };

    public shared query func icrc1_metadata() : async [ICRC1.MetaDatum] {
        ICRC1.metadata(token);
    };

    public shared query func icrc1_total_supply() : async ICRC1.Balance {
        ICRC1.total_supply(token);
    };

    public shared query func icrc1_minting_account() : async ?ICRC1.Account {
        ?ICRC1.minting_account(token);
    };

    public shared query func icrc1_balance_of(args : ICRC1.Account) : async ICRC1.Balance {
        ICRC1.balance_of(token, args);
    };

    public shared query func icrc1_supported_standards() : async [ICRC1.SupportedStandard] {
        ICRC1.supported_standards(token);
    };

    public shared({ caller }) func icrc1_transfer(args : ICRC1.TransferArgs) : async Result.Result<ICRC1.Balance, ICRC1.TransferError> {
        let res = ICRC1.transfer(token, args, caller);
        await update_canister();
        res;
    };

    public shared({ caller }) func mint(args : ICRC1.MintArgs) : async Result.Result<ICRC1.Balance, ICRC1.TransferError> {
        let res = ICRC1.mint(token, args, caller);
        await update_canister();
        res;
    };

    public shared({ caller }) func burn(args : ICRC1.BurnArgs) : async Result.Result<ICRC1.Balance, ICRC1.TransferError> {
        let res = ICRC1.burn(token, args, caller);
        await update_canister();
        res;
    };
};
