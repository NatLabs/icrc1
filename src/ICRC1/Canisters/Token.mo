import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import SB "mo:StableBuffer/StableBuffer";
import ICRC1 "../Modules/ICRC1Token";
import Archive "Archive";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Itertools "mo:itertools/Iter";
import T "../Types/Types.All";

shared ({ caller = _owner }) actor class Token(init_args : ?T.TokenTypes.TokenInitArgs) : async T.TokenTypes.FullInterface {

    //The value of this variable should only be changed by the function 'ConvertArgs'
    stable var wasInitializedWithArguments:Bool = false;
    
    private func ConvertArgs(init_arguments : ?T.TokenTypes.TokenInitArgs): ?T.TokenTypes.InitArgs
    {   
        if (init_arguments == null){

            if (wasInitializedWithArguments == false)
            {
                let infoText:Text="ERROR! Empty argument in dfx deploy is only allowed for canister updates";
                Debug.print(infoText);
                Debug.trap(infoText);                                   
            };                
            return null;            
        };


        if (wasInitializedWithArguments == true){
            let infoText:Text="ERROR! Re-initializing is not allowed";
            Debug.print(infoText);
            Debug.trap(infoText);                                               
        }
        else{
            
            var argsToUse:T.TokenTypes.TokenInitArgs = switch(init_arguments){
                case null return null; // should never happen
                case (?tokenArgs) tokenArgs;                   
            };                     

            let icrc1_args : T.TokenTypes.InitArgs = {
                        argsToUse with minting_account = Option.get( argsToUse.minting_account,{owner = _owner;subaccount = null;});
            };

            if (icrc1_args.initial_balances.size() < 1){
                if (icrc1_args.minting_allowed == false){                                        
                    let infoText:Text="ERROR! When minting feature is disabled at least one initial balances account is needed.";
                    Debug.print(infoText);
                    Debug.trap(infoText);             
                };
            }
            else{

                for ((i, (account, balance)) in Itertools.enumerate(icrc1_args.initial_balances.vals())) {               

                    if (account.owner == icrc1_args.minting_account.owner){
                        let infoText:Text="ERROR! Minting account was specified in initial balances account. This is not allowed.";
                        Debug.print(infoText);
                        Debug.trap(infoText); 

                    };
                }
            };
             
            wasInitializedWithArguments := true;            
            return Option.make(icrc1_args);               
        };                                                     
    };

    
    //Convert argument, because 'init_args' can now be null, in case of upgrade scenarios. ('dfx deploy')
    let init_arguments:?T.TokenTypes.InitArgs =  ConvertArgs(init_args);

    stable let token:T.TokenTypes.TokenData = switch (init_arguments){
        case null {
            Debug.trap("Initialize token with no arguments not allowed.");   
        };
        case (?initArgsNotNull) ICRC1.init(initArgsNotNull);
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

    public shared query func icrc1_fee() : async T.Balance {
        ICRC1.fee(token);
    };

    public shared query func icrc1_metadata() : async [T.TokenTypes.MetaDatum] {
        ICRC1.metadata(token);
    };

    public shared query func icrc1_total_supply() : async T.Balance {
        ICRC1.total_supply(token);
    };

    public shared query func icrc1_minting_account() : async ?T.AccountTypes.Account {
        ?ICRC1.minting_account(token);
    };

    public shared query func icrc1_balance_of(args : T.AccountTypes.Account) : async T.Balance {
        ICRC1.balance_of(token, args);
    };

    public shared query func icrc1_supported_standards() : async [T.TokenTypes.SupportedStandard] {
        ICRC1.supported_standards(token);
    };

    public shared ({ caller }) func icrc1_transfer(args : T.TransactionTypes.TransferArgs) : async T.TransactionTypes.TransferResult {
        await* ICRC1.transfer(token, args, caller);
    };

    public shared ({ caller }) func mint(args : T.TransactionTypes.Mint) : async T.TransactionTypes.TransferResult {                
        await* ICRC1.mint(token, args, caller);        
    };

    public shared ({ caller }) func burn(args : T.TransactionTypes.BurnArgs) : async T.TransactionTypes.TransferResult {
        await* ICRC1.burn(token, args, caller);
    };

    public shared ({ caller }) func set_name(name : Text) : async T.TokenTypes.SetTextParameterResult {
        await* ICRC1.set_name(token, name, caller);
    };

    public shared ({ caller }) func set_symbol(symbol : Text) : async T.TokenTypes.SetTextParameterResult {
        await* ICRC1.set_symbol(token, symbol, caller);
    };

    public shared ({ caller }) func set_logo(logo : Text) : async T.TokenTypes.SetTextParameterResult {
        await* ICRC1.set_logo(token, logo, caller);
    };

    public shared ({ caller }) func set_fee(fee : T.Balance) : async T.TokenTypes.SetBalanceParameterResult {
        await* ICRC1.set_fee(token, fee, caller);
    };

    public shared ({ caller }) func set_decimals(decimals : Nat8) : async T.TokenTypes.SetNat8ParameterResult {
        await* ICRC1.set_decimals(token, decimals, caller);
    };

    public shared ({ caller }) func set_min_burn_amount(min_burn_amount : T.Balance) : async T.TokenTypes.SetBalanceParameterResult {
        await* ICRC1.set_min_burn_amount(token, min_burn_amount, caller);
    };

    public shared ({ caller }) func set_minting_account(minting_account : Text) : async T.TokenTypes.SetAccountParameterResult {
        await* ICRC1.set_minting_account(token, minting_account, caller);
    };

    public shared query func min_burn_amount() : async T.Balance {
        ICRC1.min_burn_amount(token);
    };

    public shared query func get_archive() : async T.ArchiveTypes.ArchiveInterface {
        ICRC1.get_archive(token);
    };

    public shared query ({ caller }) func get_total_tx() : async Nat {
        ICRC1.total_transactions(token);
    };

    public shared query ({ caller }) func get_archive_stored_txs() : async Nat {
        ICRC1.get_archive_stored_txs(token);
    };

    // Functions for integration with the rosetta standard
    public shared query func get_transactions(req : T.TransactionTypes.GetTransactionsRequest) 
    : async T.TransactionTypes.GetTransactionsResponse {
        ICRC1.get_transactions(token, req);
    };

    // Additional functions not included in the ICRC1 standard
    public shared func get_transaction(i : T.TransactionTypes.TxIndex) : async ?T.TransactionTypes.Transaction {
        await* ICRC1.get_transaction(token, i);
    };

    // Deposit cycles into this canister.
    public shared func deposit_cycles() : async () {
        let amount = ExperimentalCycles.available();
        let accepted = ExperimentalCycles.accept(amount);
        assert (accepted == amount);
    };
};
