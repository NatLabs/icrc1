import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";

import Archive "../../src/ICRC1/Canisters/Archive";
import ICRC1 "../../src/ICRC1/";

import ActorSpec "../utils/ActorSpec";

let {
    assertTrue;
    assertFalse;
    assertAllTrue;
    describe;
    it;
    skip;
    pending;
    run;
} = ActorSpec;

func new_tx(i : Nat64) : ICRC1.Transaction {
    {
        kind = "";
        mint = null;
        burn = null;
        transfer = null;
        timestamp = i;
    };
};

// [start, end)
func txs_range(start : Nat, end : Nat) : [ICRC1.Transaction] {
    Array.tabulate(
        (end - start) : Nat,
        func(i : Nat) : ICRC1.Transaction {
            new_tx(Nat64.fromNat(start + i));
        },
    );
};

func new_txs(length : Nat) : [ICRC1.Transaction] {
    txs_range(0, length);
};

let success = run([
    describe(
        "Archive Canister",
        [
            it(
                "append_transactions()",
                do {

                    let archive = await Archive.Archive();

                    let txs = new_txs(3555);

                    assertAllTrue([
                        (await archive.total_transactions()) == 0,
                        (await archive.append_transactions(txs)) == #ok(),
                        (await archive.total_transactions()) == 3555,
                    ]);
                },
            ),
            it(
                "get_transaction()",
                do {
                    let archive = await Archive.Archive();

                    let txs = new_txs(3555);

                    let res = await archive.append_transactions(txs);

                    assertAllTrue([
                        res == #ok(),
                        (await archive.total_transactions()) == 3555,
                        (await archive.get_transaction(0)) == ?new_tx(0),
                        (await archive.get_transaction(999)) == ?new_tx(999),
                        (await archive.get_transaction(1000)) == ?new_tx(1000),
                        (await archive.get_transaction(1234)) == ?new_tx(1234),
                        (await archive.get_transaction(2829)) == ?new_tx(2829),
                        (await archive.get_transaction(3554)) == ?new_tx(3554),
                        (await archive.get_transaction(3555)) == null,
                        (await archive.get_transaction(999999)) == null,
                    ]);
                },
            ),
            it(
                "get_transactions()",
                do {
                    let archive = await Archive.Archive();

                    let txs = new_txs(5000);

                    let res = await archive.append_transactions(txs);

                    let tx_range = await archive.get_transactions({
                        start = 3251;
                        length = 2000;
                    });

                    assertAllTrue([
                        res == #ok(),
                        (await archive.total_transactions()) == 5000,
                        (await archive.get_transactions({ start = 0; length = 100 })) == txs_range(0, 100),
                        (await archive.get_transactions({ start = 225; length = 100 })) == txs_range(225, 325),
                        (await archive.get_transactions({ start = 225; length = 1200 })) == txs_range(225, 1425),
                        (await archive.get_transactions({ start = 980; length = 100 })) == txs_range(980, 1080),
                        (await archive.get_transactions({ start = 3251; length = 2000 })) == txs_range(3251, 5000),
                    ]);
                },
            ),
        ],
    ),
]);

if (success == false) {
    Debug.trap("\1b[46;41mTests failed\1b[0m");
} else {
    Debug.print("\1b[23;42;3m Success!\1b[0m");
};
