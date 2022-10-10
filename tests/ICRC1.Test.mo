import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";

import SB "mo:StableBuffer/StableBuffer";

import ActorSpec "./utils/ActorSpec";

import ICRC1 "../src/Lib/";
import U "../src/Lib/Utils";

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

let default_token_args : ICRC1.InitArgs = {
    name = "Under-Collaterised Lending Tokens";
    symbol = "UCLTs";
    decimals = 8;
    fee = 5 * (10 ** 8);
    max_supply = 1_000_000_000 * (10 ** 8);
    minting_account = canister;
    initial_balances = [];
};

let success = run([
    describe(
        "ICRC1 Token Implementation Tessts",
        [
            it(
                "init()",
                do {
                    let args = default_token_args;

                    let token = ICRC1.init(args);
                    Debug.print(debug_show (await ICRC1.get_transaction(token, 0)));

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
                    it(
                        "from an empty account",
                        do {
                            let args = default_token_args;

                            let token = ICRC1.init(args);

                            let burn_args : ICRC1.BurnArgs = {
                                from_subaccount = user1.subaccount;
                                amount = 200 * (10 ** Nat8.toNat(args.decimals));
                                memo = null;
                                created_at_time = null;
                            };

                            let prev_balance = ICRC1.balance_of(token, user1);
                            let prev_total_supply = ICRC1.total_supply(token);
                            let res = await ICRC1.burn(token, burn_args, user1.owner);

                            assertAllTrue([
                                res == #err(
                                    #InsufficientFunds {
                                        balance = 0;
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
                                // ICRC1.balance_of(token, user1) == prev.balance1 - transfer_args.amount,
                                ICRC1.balance_of(token, user2) == prev.balance2 + transfer_args.amount,
                                ICRC1.total_supply(token) == prev.total_supply,
                            ]);
                        },
                    ),
                ],
            ),
        ],
    ),
]);

if (success == false) {
    Debug.trap("\1b[46;41mTests failed\1b[0m");
} else {
    Debug.print("\1b[23;42;3m Success!\1b[0m");
};
