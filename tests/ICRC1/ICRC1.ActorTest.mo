import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";

import Itertools "mo:itertools/Iter";
import StableBuffer "mo:StableBuffer/StableBuffer";

import ActorSpec "../utils/ActorSpec";

import ICRC1 "../../src/ICRC1";
import T "../../src/ICRC1/Types";

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

        func mock_tx(to : T.Account, index : Nat) : T.Transaction {
            {
                icrc1_burn = null;
                icrc1_transfer = null;
                kind = "icrc1_mint";
                timestamp = 0;
                index;
                icrc1_mint = ?{
                    to;
                    amount = index + 1;
                    memo = null;
                    created_at_time = null;
                };
            };
        };

        let canister : T.Account = {
            owner = Principal.fromText("x4ocp-k7ot7-oiqws-rg7if-j4q2v-ewcel-2x6we-l2eqz-rfz3e-6di6e-jae");
            subaccount = null;
        };

        let user1 : T.Account = {
            owner = Principal.fromText("prb4z-5pc7u-zdfqi-cgv7o-fdyqf-n6afm-xh6hz-v4bk4-kpg3y-rvgxf-iae");
            subaccount = null;
        };

        let user2 : T.Account = {
            owner = Principal.fromText("ygyq4-mf2rf-qmcou-h24oc-qwqvv-gt6lp-ifvxd-zaw3i-celt7-blnoc-5ae");
            subaccount = null;
        };

        func is_tx_equal(t1 : T.Transaction, t2 : T.Transaction) : Bool {
            { t1 with timestamp = 0 } == { t2 with timestamp = 0 };
        };

        func is_opt_tx_equal(t1 : ?T.Transaction, t2 : ?T.Transaction) : Bool {
            switch (t1, t2) {
                case (?t1, ?t2) {
                    is_tx_equal(t1, t2);
                };
                case (_, ?t2) { false };
                case (?t1, _) { false };
                case (_, _) { true };
            };
        };

        func create_mints(token : T.TokenData, minting_principal : Principal, n : Nat) : async () {
            for (i in Itertools.range(0, n)) {
                ignore await* ICRC1.mint(
                    token,
                    {
                        to = user1;
                        amount = i + 1;
                        memo = null;
                        created_at_time = null;
                    },
                    minting_principal,
                );
            };
        };

        let default_token_args : T.InitArgs = {
            name = "Under-Collaterised Lending Tokens";
            symbol = "UCLTs";
            decimals = 8;
            fee = 5 * (10 ** 8);
            max_supply = 1_000_000_000 * (10 ** 8);
            minting_account = canister;
            initial_balances = [];
            min_burn_amount = (10 * (10 ** 8));
            advanced_settings = null;
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
                            token._fee == args.fee,
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

                        let token = ICRC1.init({ args 
                            with initial_balances = [
                                (user1, 100),
                                (user2, 200),
                            ];
                        });

                        assertAllTrue([
                            ICRC1.balance_of(token, user1) == 100,
                            ICRC1.balance_of(token, user2) == 200,
                        ]);
                    },
                ),
                it(
                    "total_supply()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init({ args 
                            with initial_balances = [
                                (user1, 100),
                                (user2, 200),
                            ];
                        });

                        assertTrue(
                            ICRC1.total_supply(token) == 300,
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
                                url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-1";
                            }],
                        );
                    },
                ),

                it(
                    "mint()",
                    do {
                        let args = default_token_args;

                        let token = ICRC1.init(args);

                        let mint_args : T.Mint = {
                            to = user1;
                            amount = 200 * (10 ** Nat8.toNat(args.decimals));
                            memo = null;
                            created_at_time = null;
                        };

                        let res = await* ICRC1.mint(
                            token,
                            mint_args,
                            args.minting_account.owner,
                        );

                        assertAllTrue([
                            res == #Ok(0),
                            ICRC1.balance_of(token, user1) == mint_args.amount,
                            ICRC1.balance_of(token, args.minting_account) == 0,
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

                                let mint_args : T.Mint = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ICRC1.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                );

                                let burn_args : T.BurnArgs = {
                                    from_subaccount = user1.subaccount;
                                    amount = 50 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                let prev_balance = ICRC1.balance_of(token, user1);
                                let prev_total_supply = ICRC1.total_supply(token);

                                let res = await* ICRC1.burn(token, burn_args, user1.owner);

                                assertAllTrue([
                                    res == #Ok(1),
                                    ICRC1.balance_of(token, user1) == ((prev_balance - burn_args.amount) : Nat),
                                    ICRC1.total_supply(token) == ((prev_total_supply - burn_args.amount) : Nat),
                                ]);
                            },
                        ),
                        it(
                            "from an empty account",
                            do {
                                let args = default_token_args;

                                let token = ICRC1.init(args);

                                let burn_args : T.BurnArgs = {
                                    from_subaccount = user1.subaccount;
                                    amount = 200 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                let prev_balance = ICRC1.balance_of(token, user1);
                                let prev_total_supply = ICRC1.total_supply(token);
                                let res = await* ICRC1.burn(token, burn_args, user1.owner);

                                assertAllTrue([
                                    res == #Err(
                                        #InsufficientFunds {
                                            balance = 0;
                                        },
                                    ),
                                ]);
                            },
                        ),
                        it(
                            "burn amount less than min_burn_amount",
                            do {
                                let args = default_token_args;

                                let token = ICRC1.init(args);

                                let mint_args : T.Mint = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ICRC1.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                );

                                let burn_args : T.BurnArgs = {
                                    from_subaccount = user1.subaccount;
                                    amount = 5 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = await* ICRC1.burn(token, burn_args, user1.owner);

                                assertAllTrue([
                                    res == #Err(
                                        #BadBurn {
                                            min_burn_amount = 10 * (10 ** 8);
                                        },
                                    ),
                                ]);
                            },
                        ),
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

                                ignore await* ICRC1.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                );

                                let transfer_args : T.TransferArgs = {
                                    from_subaccount = user1.subaccount;
                                    to = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token._fee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = await* ICRC1.transfer(
                                    token,
                                    transfer_args,
                                    user1.owner,
                                );


                                assertAllTrue([
                                    res == #Ok(1),
                                    ICRC1.balance_of(token, user1) == ICRC1.balance_from_float(token, 145),
                                    token._burned_tokens == ICRC1.balance_from_float(token, 5),
                                    ICRC1.balance_of(token, user2) == ICRC1.balance_from_float(token, 50),
                                    ICRC1.total_supply(token) == ICRC1.balance_from_float(token, 195),
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
                                                    (await* ICRC1.get_transaction(token, 0)),
                                                    ?mock_tx(user1, 0),
                                                ),
                                                is_opt_tx_equal(
                                                    (await* ICRC1.get_transaction(token, 1234)),
                                                    ?mock_tx(user1, 1234),
                                                ),
                                                is_opt_tx_equal(
                                                    (await* ICRC1.get_transaction(token, 2000)),
                                                    ?mock_tx(user1, 2000),
                                                ),
                                                is_opt_tx_equal(
                                                    (await* ICRC1.get_transaction(token, 4100)),
                                                    ?mock_tx(user1, 4100),
                                                ),
                                                is_opt_tx_equal(
                                                    (await* ICRC1.get_transaction(token, 4122)),
                                                    ?mock_tx(user1, 4122),
                                                ),
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
