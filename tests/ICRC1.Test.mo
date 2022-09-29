import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";

import SB "mo:StableBuffer/StableBuffer";

import ActorSpec "./utils/ActorSpec";

import ICRC1 "../src/";
import U "../src/Utils";


let {
    assertTrue; assertFalse; assertAllTrue; describe; it; skip; pending; run
} = ActorSpec;

let controller : ICRC1.Account = {
    owner = Principal.fromText("ygyq4-mf2rf-qmcou-h24oc-qwqvv-gt6lp-ifvxd-zaw3i-celt7-blnoc-5ae");
    subaccount = null;
};

let canister : ICRC1.Account = {
    owner = Principal.fromText("x4ocp-k7ot7-oiqws-rg7if-j4q2v-ewcel-2x6we-l2eqz-rfz3e-6di6e-jae");
    subaccount = null;
};

let default_token_args : ICRC1.InitArgs = {
    name = "Under-Collaterised Lending Tokens";
    symbol = "UCLTs";
    decimals = 8;
    fee = 5 * (10 ** 8);
    max_supply = 1_000_000_000 * (10 ** 8);
    minting_account = canister;
    store_transactions = false;
};

let success = run([
    describe("ICRC1 Token Implementation Tessts", [
        it("init()", do {
            let args = default_token_args;

            let icrc1_token= ICRC1.init(args);
            
            U.debug_icrc1_data(icrc1_token);

            // returns without trapping
            assertAllTrue ([
                icrc1_token.name == args.name,
                icrc1_token.symbol == args.symbol,
                icrc1_token.decimals == args.decimals,
                icrc1_token.fee == args.fee,
                icrc1_token.max_supply == args.max_supply,

                icrc1_token.minting_account == args.minting_account,
                icrc1_token.store_transactions == args.store_transactions,
                SB.toArray(icrc1_token.supported_standards) == [U.default_standard],
                SB.size(icrc1_token.transactions) == 0,
            ]);
        }),

        it("icrc1_name()", do{
            let args = default_token_args;

            let icrc1_token= ICRC1.init(args);

            assertTrue(
                ICRC1.icrc1_name(icrc1_token) == args.name
            )
        }),

        it("icrc1_symbol()", do{
            let args = default_token_args;

            let icrc1_token= ICRC1.init(args);

            assertTrue(
                ICRC1.icrc1_symbol(icrc1_token) == args.symbol
            )
        }),

        it("icrc1_decimals()", do{
            let args = default_token_args;

            let icrc1_token= ICRC1.init(args);

            assertTrue(
                ICRC1.icrc1_decimals(icrc1_token) == args.decimals
            )
        }),
        it("icrc1_fee()", do{
            let args = default_token_args;

            let icrc1_token= ICRC1.init(args);

            assertTrue(
                ICRC1.icrc1_fee(icrc1_token) == args.fee
            )
        }),
        it("icrc1_minting_account()", do{
            let args = default_token_args;

            let icrc1_token= ICRC1.init(args);

            assertTrue(
                ICRC1.icrc1_minting_account(icrc1_token) == args.minting_account
            )
        }),
        it("icrc1_balance_of()", do{
            let args = default_token_args;

            let icrc1_token= ICRC1.init(args);

            assertTrue(
                ICRC1.icrc1_balance_of(
                    icrc1_token, 
                    icrc1_token.minting_account
                ) == args.max_supply
            )
        }),

        it("icrc1_total_supply()", do{
            let args = default_token_args;

            let icrc1_token= ICRC1.init(args);

            assertTrue(
                ICRC1.icrc1_total_supply(icrc1_token) == 0
            )
        }),
    ])
]);

if(success == false){
  Debug.trap("\1b[46;41mTests failed\1b[0m");
}else{
    Debug.print("\1b[23;42;3m Success!\1b[0m");
};
