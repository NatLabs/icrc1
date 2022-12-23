import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";

import Itertools "mo:itertools/Iter";
import StableBuffer "mo:StableBuffer/StableBuffer";

import ActorSpec "../utils/ActorSpec";

import ICRC1 "../../src/ICRC1/";
import U "../../src/ICRC1/Utils";

module {
    public func test() : async ActorSpec.Group {

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

        let { SB } = U;

        func add_decimals(n : Nat, decimals : Nat) : Nat {
            n * (10 ** decimals);
        };

        func mock_tx(to : ICRC1.Account, amount : Nat) : ICRC1.Transaction {
            {
                burn = null;
                transfer = null;
                kind = "MINT";
                timestamp = 0;
                mint = ?{
                    to;
                    amount;
                    memo = null;
                    created_at_time = null;
                };
            };
        };

        let canister : ICRC1.Account = {
            owner = Principal.fromText("x4ocp-k7ot7-oiqws-rg7if-j4q2v-ewcel-2x6we-l2eqz-rfz3e-6di6e-jae");
            subaccount = null;
        };

        let user1 : ICRC1.Account = {
            owner = Principal.fromText("prb4z-5pc7u-zdfqi-cgv7o-fdyqf-n6afm-xh6hz-v4bk4-kpg3y-rvgxf-iae");
            subaccount = null;
        };

        let user2 : ICRC1.Account = {
            owner = Principal.fromText("ygyq4-mf2rf-qmcou-h24oc-qwqvv-gt6lp-ifvxd-zaw3i-celt7-blnoc-5ae");
            subaccount = null;
        };

        func txs_range(start : Nat, end : Nat) : [ICRC1.Transaction] {
            Array.tabulate(
                (end - start) : Nat,
                func(i : Nat) : ICRC1.Transaction {
                    mock_tx(user1, start + i);
                },
            );
        };

        func is_tx_equal(t1 : ICRC1.Transaction, t2 : ICRC1.Transaction) : Bool {
            { t1 with timestamp = 0 } == { t2 with timestamp = 0 };
        };

        func is_opt_tx_equal(t1 : ?ICRC1.Transaction, t2 : ?ICRC1.Transaction) : Bool {
            switch (t1, t2) {
                case (?t1, ?t2) {
                    is_tx_equal(t1, t2);
                };
                case (_, ?t2) { false };
                case (?t1, _) { false };
                case (_, _) { true };
            };
        };

        func validate_get_transactions(token : ICRC1.TokenData, tx_req : ICRC1.GetTransactionsRequest, tx_res : ICRC1.TxResponseWithoutCallback) : Bool {
            let { archive } = token;

            let token_start = 0;
            let token_end = ICRC1.total_transactions(token);

            let req_start = tx_req.start;
            let req_end = tx_req.start + tx_req.length;

            var log_length = 0;

            if (req_start < token_end) {
                log_length := (Nat.min(token_end, req_end) - Nat.max(token_start, req_start)) : Nat;
            };

            if (log_length != tx_res.log_length) {
                Debug.print("Failed at log_length: " # Nat.toText(log_length) # " != " # Nat.toText(tx_res.log_length));
                return false;
            };

            var txs_size = 0;
            if (req_end > archive.stored_txs and req_start <= token_end) {
                txs_size := Nat.min(req_end, token_end) - archive.stored_txs;
            };

            if (txs_size != tx_res.transactions.size()) {
                Debug.print("Failed at txs_size: " # Nat.toText(txs_size) # " != " # Nat.toText(tx_res.transactions.size()));
                return false;
            };

            if (txs_size > 0) {
                for (i in Iter.range(0, txs_size - 1)) {
                    let tx = tx_res.transactions[i];
                    let mocked_tx = mock_tx(user1, archive.stored_txs + i);

                    if (not is_tx_equal(tx, mocked_tx)) {
                        Debug.print("Failed at tx: " # debug_show (tx) # " != " # debug_show (mocked_tx));
                        return false;
                    };
                };
            };

            true;
        };

        func are_txs_equal(t1 : [ICRC1.Transaction], t2 : [ICRC1.Transaction]) : Bool {
            Itertools.equal<ICRC1.Transaction>(t1.vals(), t2.vals(), is_tx_equal);
        };

        func create_mints(token : ICRC1.TokenData, minting_principal : Principal, n : Nat) : async () {
            for (i in Itertools.range(0, n)) {
                ignore await ICRC1.mint(
                    token,
                    {
                        to = user1;
                        amount = i;
                        memo = null;
                        created_at_time = null;
                    },
                    minting_principal,
                );
            };
        };

        let default_token_args : ICRC1.InitArgs = {
            name = "Under-Collaterised Lending Tokens";
            symbol = "UCLTs";
            decimals = 8;
            fee = 5 * (10 ** 8);
            max_supply = 1_000_000_000 * (10 ** 8);
            minting_account = canister;
            initial_balances = [];
            permitted_drift = null;
            transaction_window = null;
        };

        return describe(
            "ICRC1 Token Implementation Tessts",
            [
                it(
                    "init()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        // returns without trapping
                        assertAllTrue([
                            token.name == args.name,
                            token.symbol == args.symbol,
                            token.decimals == args.decimals,
                            token.fee == args.fee,
                            token.max_supply == args.max_supply,

                            token.minting_account == args.minting_account,
                            SB.toArray(token.supported_standards) == [U.default_standard],
                            SB.size(token.transactions) == 0,
                        ]);
                    },
                ),

                it(
                    "name()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        assertTrue(
                            ICRC1.name(token) == args.name,
                        );
                    },
                ),

                it(
                    "symbol()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        assertTrue(
                            ICRC1.symbol(token) == args.symbol,
                        );
                    },
                ),

                it(
                    "decimals()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        assertTrue(
                            ICRC1.decimals(token) == args.decimals,
                        );
                    },
                ),
                it(
                    "fee()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        assertTrue(
                            ICRC1.fee(token) == args.fee,
                        );
                    },
                ),
                it(
                    "minting_account()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        assertTrue(
                            ICRC1.minting_account(token) == args.minting_account,
                        );
                    },
                ),
                it(
                    "balance_of()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        assertTrue(
                            ICRC1.balance_of(
                                token,
                                token.minting_account,
                            ) == args.max_supply,
                        );
                    },
                ),

                it(
                    "total_supply()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        assertTrue(
                            ICRC1.total_supply(token) == 0,
                        );
                    },
                ),

                it(
                    "metadata()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        assertTrue(
                            ICRC1.metadata(token) == [
                                ("icrc1:fee", #Nat(args.fee)),
                                ("icrc1:name", #Text(args.name)),
                                ("icrc1:symbol", #Text(args.symbol)),
                                ("icrc1:decimals", #Nat(Nat8.toNat(args.decimals))),
                            ],
                        );
                    },
                ),

                it(
                    "supported_standards()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        assertTrue(
                            ICRC1.supported_standards(token) == [{
                                name = "ICRC-1";
                                url = "https://github.com/dfinity/ICRC-1";
                            }],
                        );
                    },
                ),

                it(
                    "mint()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        let mint_args : ICRC1.Mint = {
                            to = user1;
                            amount = 200 * (10 ** Nat8.toNat(args.decimals));
                            memo = null;
                            created_at_time = null;
                        };

                        let res = await ICRC1.mint(
                            token,
                            mint_args,
                            args.minting_account.owner,
                        );

                        assertAllTrue([
                            res == #ok(mint_args.amount),
                            ICRC1.balance_of(token, user1) == mint_args.amount,
                            ICRC1.balance_of(token, args.minting_account) == args.max_supply - mint_args.amount,
                            ICRC1.total_supply(token) == mint_args.amount,
                        ]);
                    },
                ),

                describe(
                    "burn()",
                    [
                        it(
                            "from funded account",
                            do {
                                let args = default_token_args;

                                let token = ICRC1.init(args);

                                let mint_args : ICRC1.Mint = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await ICRC1.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                );

                                let burn_args : ICRC1.BurnArgs = {
                                    from_subaccount = user1.subaccount;
                                    amount = 50 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                let prev_balance = ICRC1.balance_of(token, user1);
                                let prev_total_supply = ICRC1.total_supply(token);

                                let res = await ICRC1.burn(token, burn_args, user1.owner);

                                assertAllTrue([
                                    res == #ok(burn_args.amount),
                                    ICRC1.balance_of(token, user1) == prev_balance - burn_args.amount,
                                    ICRC1.total_supply(token) == prev_total_supply - burn_args.amount,
                                ]);
                            },
                        ),
                        // it(
                        //     "from an empty account",
                        //     do {
                        //         let args = default_token_args;

                        //         let token = ICRC1.init(args);

                        //         let burn_args : ICRC1.BurnArgs = {
                        //             from_subaccount = user1.subaccount;
                        //             amount = 200 * (10 ** Nat8.toNat(args.decimals));
                        //             memo = null;
                        //             created_at_time = null;
                        //         };

                        //         let prev_balance = ICRC1.balance_of(token, user1);
                        //         let prev_total_supply = ICRC1.total_supply(token);
                        //         let res = await ICRC1.burn(token, burn_args, user1.owner);

                        //         assertAllTrue([
                        //             res == #err(
                        //                 #InsufficientFunds {
                        //                     balance = 0;
                        //                 },
                        //             ),
                        //         ]);
                        //     },
                        // ),
                    ],
                ),
                describe(
                    "transfer()",
                    [
                        it(
                            "Transfer from funded account",
                            do {
                                let args = default_token_args;
                                let token = ICRC1.init(args);

                                let mint_args = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await ICRC1.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                );

                                let transfer_args : ICRC1.TransferArgs = {
                                    from_subaccount = user1.subaccount;
                                    to = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.fee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let prev = {
                                    balance1 = ICRC1.balance_of(token, user1);
                                    balance2 = ICRC1.balance_of(token, user2);
                                    total_supply = ICRC1.total_supply(token);
                                };

                                let res = await ICRC1.transfer(
                                    token,
                                    transfer_args,
                                    user1.owner,
                                );

                                assertAllTrue([
                                    res == #ok(transfer_args.amount),
                                    ICRC1.balance_of(token, user1) == prev.balance1 - transfer_args.amount,
                                    ICRC1.balance_of(token, user2) == prev.balance2 + transfer_args.amount,
                                    ICRC1.total_supply(token) == prev.total_supply,
                                ]);
                            },
                        ),
                    ],
                ),

                describe(
                    "Internal Archive Testing",
                    [
                        describe(
                            "A token canister with 4123 total txs",
                            do {
                                let args = default_token_args;
                                let token = ICRC1.init(args);

                                await create_mints(token, canister.owner, 4123);
                                [
                                    it(
                                        "Archive has 4000 stored txs",
                                        do {

                                            assertAllTrue([
                                                token.archive.stored_txs == 4000,
                                                SB.size(token.transactions) == 123,
                                                SB.capacity(token.transactions) == ICRC1.MAX_TRANSACTIONS_IN_LEDGER,
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transaction() works for txs in the archive and ledger canister",
                                        do {
                                            assertAllTrue([
                                                is_opt_tx_equal(
                                                    (await ICRC1.get_transaction(token, 0)),
                                                    ?mock_tx(user1, 0),
                                                ),
                                                is_opt_tx_equal(
                                                    (await ICRC1.get_transaction(token, 1234)),
                                                    ?mock_tx(user1, 1234),
                                                ),
                                                is_opt_tx_equal(
                                                    (await ICRC1.get_transaction(token, 2000)),
                                                    ?mock_tx(user1, 2000),
                                                ),
                                                is_opt_tx_equal(
                                                    (await ICRC1.get_transaction(token, 4100)),
                                                    ?mock_tx(user1, 4100),
                                                ),
                                                is_opt_tx_equal(
                                                    (await ICRC1.get_transaction(token, 4122)),
                                                    ?mock_tx(user1, 4122),
                                                ),
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transactions from 0 to 2000",
                                        do {
                                            let req = {
                                                start = 0;
                                                length = 2000;
                                            };

                                            let res = (
                                                await ICRC1.get_transactions(
                                                    token,
                                                    req,
                                                ),
                                            );

                                            assertAllTrue([
                                                validate_get_transactions(token, req, res),
                                                res.archived_transactions == [{
                                                    start = 0;
                                                    length = 2000;
                                                }],
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transactions from 3000 to 4123",
                                        do {
                                            let req = {
                                                start = 3000;
                                                length = 1123;
                                            };

                                            let res = (
                                                await ICRC1.get_transactions(
                                                    token,
                                                    req,
                                                ),
                                            );

                                            assertAllTrue([
                                                validate_get_transactions(token, req, res),
                                                res.archived_transactions == [{
                                                    start = 3000;
                                                    length = 1000;
                                                }],
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transactions from 4000 to 4123",
                                        do {
                                            let req = {
                                                start = 4000;
                                                length = 123;
                                            };

                                            let res = (
                                                await ICRC1.get_transactions(
                                                    token,
                                                    req,
                                                ),
                                            );

                                            assertAllTrue([
                                                validate_get_transactions(token, req, res),
                                                res.archived_transactions == [],
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transactions exceeding the txs in the ledger (0 to 5000)",
                                        do {
                                            let req = {
                                                start = 0;
                                                length = 5000;
                                            };

                                            let res = (
                                                await ICRC1.get_transactions(
                                                    token,
                                                    req,
                                                ),
                                            );

                                            assertAllTrue([
                                                validate_get_transactions(token, req, res),
                                                res.archived_transactions == [{
                                                    start = 0;
                                                    length = 4000;
                                                }],
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transactions outside the txs range (5000 to 6000)",
                                        do {
                                            let req = {
                                                start = 5000;
                                                length = 1000;
                                            };

                                            let res = (
                                                await ICRC1.get_transactions(
                                                    token,
                                                    req,
                                                ),
                                            );

                                            assertAllTrue([
                                                validate_get_transactions(token, req, res),
                                                res.archived_transactions == [],
                                            ]);
                                        },
                                    ),
                                ];
                            },
                        ),
                    ],
                ),
            ],
        );
    };
};
