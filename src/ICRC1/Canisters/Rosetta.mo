import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Result "mo:base/Result";

import SB "mo:StableBuffer/StableBuffer";

import ICRC1 "../";
import Archive "Archive";

shared ({ caller = _owner }) actor class Token(
    token_args : ICRC1.TokenInitArgs,
) : async ICRC1.TokenInterface {

    let token = ICRC1.init({
        token_args with minting_account = Option.get(
            token_args.minting_account,
            {
                owner = _owner;
                subaccount = null;
            },
        );
    });

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

    public shared ({ caller }) func icrc1_transfer(args : ICRC1.TransferArgs) : async Result.Result<ICRC1.Balance, ICRC1.TransferError> {
        await ICRC1.transfer(token, args, caller);
    };

    public shared ({ caller }) func mint(args : ICRC1.Mint) : async Result.Result<ICRC1.Balance, ICRC1.TransferError> {
        await ICRC1.mint(token, args, caller);
    };

    public shared ({ caller }) func burn(args : ICRC1.BurnArgs) : async Result.Result<ICRC1.Balance, ICRC1.TransferError> {
        await ICRC1.burn(token, args, caller);
    };

    // Functions from the rosetta icrc1 ledger

    // This should be a query fn but inter-canister query calls are not supported yet
    public shared func get_transactions(req : ICRC1.GetTransactionsRequest) : async ICRC1.GetTransactionsResponse {
        let res = await ICRC1.get_transactions(token, req);
        let archived_txs_with_shared_callback = Array.map(
            res.archived_transactions,
            func(archived_tx : ICRC1.GetTransactionsRequest) : ICRC1.ArchivedTransaction {

                let callback = shared func(req : ICRC1.GetTransactionsRequest) : async ICRC1.TransactionRange {
                    let archived_txs = await token.archive.canister.get_transactions(req);

                    { transactions = archived_txs };
                };

                { archived_tx with callback };
            },
        );

        {
            res with archived_transactions = archived_txs_with_shared_callback;
        };
    };

    // Useful functions not included in ICRC1 or Rosetta
    public shared func get_transaction(token_id : Nat) : async ?ICRC1.Transaction {
        await ICRC1.get_transaction(token, token_id);
    };
};
