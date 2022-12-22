import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Time "mo:base/Time";

import ICRC1 "../../src/ICRC1/";

type TokenInitArgs = {
    name : Text;
    symbol : Text;
    decimals : Nat8;
    fee : ICRC1.Balance;
    max_supply : ICRC1.Balance;
    initial_balances : [(ICRC1.Account, ICRC1.Balance)];
    minting_account : ?ICRC1.Account;
    permitted_drift : ?Time.Time;
    transaction_window : ?Time.Time;
};

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
    
    // This would be better as a query fn but inter-canister query calls are not supported yet
    public shared func get_transactions(req : ICRC1.GetTransactionsRequest) : async ICRC1.GetTransactionsResponse {
        await ICRC1.get_transactions(token, req);
    };

    // Useful functions not included in ICRC1 or Rosetta
    public shared func get_transaction(token_id : Nat) : async ?ICRC1.Transaction {
        await ICRC1.get_transaction(token, token_id);
    };
};
