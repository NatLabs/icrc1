import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import SB "mo:StableBuffer/StableBuffer";
import ICRC1 ".."; // This is lib.mo
import Archive "Archive";
import Principal "mo:base/Principal";
import T "../Types";
import Debug "mo:base/Debug";
import Error "mo:base/Error";

shared ({ caller = _owner }) actor class Token(init_args : ?ICRC1.TokenInitArgs) : async ICRC1.FullInterface {

  
    //The value of this variable should only be changed by the function 'ConvertArgs'
    stable var wasInitializedWithArguments:Bool = false;
    
    private func ConvertArgs(init_arguments : ?ICRC1.TokenInitArgs): T.InitArgs
    {        
        if (init_arguments == null and wasInitializedWithArguments == false)
        {
            let infoText:Text="ERROR! Empty argument in dfx deploy is only allowed for canister updates";
            Debug.print(infoText);

            //Don't know how else we can cause exception, so that the deploy process will fail
            var dummyVariable:Nat = 0;
            dummyVariable := 0/0;
            
        };

        //Default Token-Init-Arguments.
        //This is only used if no parameter was used during 'dfx deploy'
        //-> The stable var 'token' will not be changed by this, because the value of the stable var 'token' 
        //   was already set.        
        //So this is only dummy-variable in some sense, so we are able to omit arguments for 'dfx deploy'.
        let defaultArgs:ICRC1.TokenInitArgs =   
        {
            name ="blabla";
            symbol ="symbol";
            decimals =8;
            fee = 100000;
            logo = "";
            minting_account = null;
            max_supply = 100000000;
            initial_balances = [({owner = Principal.fromText("aaaaa-aa");subaccount = null;},10000)];
            min_burn_amount = 100;       
            advanced_settings = null;  
        } ;
        
        var argsToUse:ICRC1.TokenInitArgs = switch(init_arguments){
            case null defaultArgs;
            case (?TokenInitArgs) TokenInitArgs;
        };
            
        let icrc1_args : ICRC1.InitArgs = {
            argsToUse with minting_account = Option.get(
                argsToUse.minting_account,
                {
                    owner = _owner;
                    subaccount = null;
                },
            );
        };
        if (init_arguments != null)
        {
            wasInitializedWithArguments := true;
        };

        return icrc1_args;
        
    };

    
    //Convert argument, because 'init_args' can now be null, in case of upgrade scenarios. ('dfx deploy')
    let init_arguments:T.InitArgs =  ConvertArgs(init_args);

    stable let token = ICRC1.init(init_arguments);


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

    public shared ({ caller }) func icrc1_transfer(args : ICRC1.TransferArgs) : async ICRC1.TransferResult {
        await* ICRC1.transfer(token, args, caller);
    };

    public shared ({ caller }) func mint(args : ICRC1.Mint) : async ICRC1.TransferResult {
        return #Err(
            #GenericError {
                error_code = 401;
                message = "Unauthorized: Minting is not allowed.";
            }
        );
    };

    public shared ({ caller }) func burn(args : ICRC1.BurnArgs) : async ICRC1.TransferResult {
        await* ICRC1.burn(token, args, caller);
    };

    public shared ({ caller }) func set_name(name : Text) : async ICRC1.SetTextParameterResult {
        await* ICRC1.set_name(token, name, caller);
    };

    public shared ({ caller }) func set_symbol(symbol : Text) : async ICRC1.SetTextParameterResult {
        await* ICRC1.set_symbol(token, symbol, caller);
    };

    public shared ({ caller }) func set_logo(logo : Text) : async ICRC1.SetTextParameterResult {
        await* ICRC1.set_logo(token, logo, caller);
    };

    public shared ({ caller }) func set_fee(fee : ICRC1.Balance) : async ICRC1.SetBalanceParameterResult {
        await* ICRC1.set_fee(token, fee, caller);
    };

    public shared ({ caller }) func set_decimals(decimals : Nat8) : async ICRC1.SetNat8ParameterResult {
        await* ICRC1.set_decimals(token, decimals, caller);
    };

    public shared ({ caller }) func set_min_burn_amount(min_burn_amount : ICRC1.Balance) : async ICRC1.SetBalanceParameterResult {
        await* ICRC1.set_min_burn_amount(token, min_burn_amount, caller);
    };

    public shared ({ caller }) func set_minting_account(minting_account : Text) : async ICRC1.SetAccountParameterResult {
        await* ICRC1.set_minting_account(token, minting_account, caller);
    };

    public shared query func min_burn_amount() : async ICRC1.Balance {
        ICRC1.min_burn_amount(token);
    };

    public shared query func get_archive() : async ICRC1.ArchiveInterface {
        ICRC1.get_archive(token);
    };

    public shared query ({ caller }) func get_total_tx() : async Nat {
        ICRC1.total_transactions(token);
    };

    public shared query ({ caller }) func get_archive_stored_txs() : async Nat {
        ICRC1.get_archive_stored_txs(token);
    };

    // Functions for integration with the rosetta standard
    public shared query func get_transactions(req : ICRC1.GetTransactionsRequest) : async ICRC1.GetTransactionsResponse {
        ICRC1.get_transactions(token, req);
    };

    // Additional functions not included in the ICRC1 standard
    public shared func get_transaction(i : ICRC1.TxIndex) : async ?ICRC1.Transaction {
        await* ICRC1.get_transaction(token, i);
    };

    // Deposit cycles into this canister.
    public shared func deposit_cycles() : async () {
        let amount = ExperimentalCycles.available();
        let accepted = ExperimentalCycles.accept(amount);
        assert (accepted == amount);
    };
};
