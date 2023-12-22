import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Time "mo:base/Time";
import List "mo:base/List";
import { setTimer; recurringTimer;cancelTimer } = "mo:base/Timer";
import Nat "mo:base/Nat";
import Cycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import SB "mo:StableBuffer/StableBuffer";
import ICRC1 "../Modules/ICRC1Token";
import Archive "Archive";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Itertools "mo:itertools/Iter";
import Trie "mo:base/Trie";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import T "../Types/Types.All";
import Constants "../Types/Types.Constants";
import Account "../Modules/Account";

/// The actor class for the main token
shared ({ caller = _owner }) actor class Token(init_args : ?T.TokenTypes.TokenInitArgs) : async T.TokenTypes.FullInterface = this{

    //The value of this variable should only be changed by the function 'ConvertArgs'
    private stable var wasInitializedWithArguments:Bool = false;
    private stable var archive_canisterIds: T.ArchiveTypes.ArchiveCanisterIds = {var canisterIds = List.nil<Principal>()};
    private stable var tokenCanisterId:Principal = Principal.fromText("aaaaa-aa");

    private stable var autoTopupData:T.CanisterTypes.CanisterAutoTopUpData = {
        var autoCyclesTopUpEnabled = false;
        var autoCyclesTopUpMinutes:Nat = 60 * 12; //12 hours
        var autoCyclesTopUpTimerId:Nat = 0;
        var autoCyclesTopUpOccuredNumberOfTimes:Nat = 0;
    };
   
    
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
             
            //Now check the balance of cycles available:
            let amount = Cycles.balance();            
            if (amount < Constants.TOKEN_INITIAL_CYCLES_REQUIRED){
                        let missingBalance:Nat = Constants.TOKEN_INITIAL_CYCLES_REQUIRED - amount;
                        let infoText:Text="\r\nERROR! At least "  #debug_show(Constants.TOKEN_INITIAL_DEPLOYMENT_CYCLES_REQUIRED) 
                        #" cycles are needed for deployment. \r\n "
                        #"- Available cycles: " #debug_show(amount)#"\r\n" 
                        #"- Missing cycles: " #debug_show(missingBalance)#"\r\n" 
                        #" -> You can use the '--with-cycles' command in dfx deploy. \r\n"
                        #"    For example: \r\n"
                        #"    'dfx deploy icrc1 --with-cycles 3000000000000'";                         
                        Debug.print(infoText);
                        Debug.trap(infoText);
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
        
        await* ICRC1.transfer(token, args, caller, archive_canisterIds);       
    };

    public shared ({ caller }) func mint(args : T.TransactionTypes.Mint) : async T.TransactionTypes.TransferResult {                        
        await* ICRC1.mint(token, args, caller, archive_canisterIds);                          
    };

    public shared ({ caller }) func burn(args : T.TransactionTypes.BurnArgs) : async T.TransactionTypes.TransferResult {
        
        await* ICRC1.burn(token, args, caller, archive_canisterIds);        
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
        let amount = Cycles.available();
        let accepted = Cycles.accept(amount);
        assert (accepted == amount);
    };

    public shared query func cycles_balance(): async Nat {
        Cycles.balance();        
    };

    /// Retrieve information for the main token and all dynamically added archive canisters:
    /// - The balance for each canister is shown
    /// - The canister-id for each canister is shown when this function is called by the minting-owner 
    public shared ({ caller }) func all_canister_stats(): async [T.CanisterTypes.CanisterStatsResponse]{
          if (tokenCanisterId == Principal.fromText("aaaaa-aa")){
             tokenCanisterId := Principal.fromActor(this);
       };
       let balance = Cycles.balance();
       let hidePrincipals:Bool = caller != token.minting_account.owner;
       await* ICRC1.all_canister_stats(hidePrincipals, tokenCanisterId, balance, archive_canisterIds);      
    };

    /// Show the token holders
    public shared query func get_holders_count(): async Nat{
        token.accounts._size;
    };

    /// Get list of the holders
    /// The list can contain maximum 5000 entries. Therefore the additional 'index' and 'count' parameter in case
    /// there are more than 5000 entries available.
    public shared query func get_holders(index:?Nat, count:?Nat): async [T.AccountTypes.AccountBalanceInfo]{           
        ICRC1.get_holders(token, index, count);                    
    };


    ///This function enables the timer to auto fill the dynamically created archive canisters 
    public shared ({ caller }) func auto_topup_cycles_enable(minutes:?Nat) : async Result.Result<Text,Text> {

        if (caller != token.minting_account.owner) {                        
            return #err("Unauthorized: Only minting account can call this function..");
        }; 

        let minutesToUse:Nat = switch(minutes){
            case (?minutes) minutes;
            case (null) 60 * 12; //12 hours
        };

        if (minutesToUse < 15){
            return #err("Error. At least 15 minutes timer is required.");
        };

        if (autoTopupData.autoCyclesTopUpEnabled == false or minutesToUse != autoTopupData.autoCyclesTopUpMinutes)  {
                autoTopupData.autoCyclesTopUpMinutes:=minutesToUse;
                auto_topup_cycles_enable_internal();
                #ok("Automatic cycles topUp for archive canisters is now enabled. Check every " # debug_show(autoTopupData.autoCyclesTopUpMinutes) #" minutes.");
        }
        else{
                #ok("Automatic cycles topUp for archive canisters was already enabled. Check every " # debug_show(autoTopupData.autoCyclesTopUpMinutes) #" minutes.");
        };
            
    };

    /// This functions disables the auto fill up timer
    public shared({ caller }) func auto_topup_cycles_disable() : async Result.Result<Text,Text> {
        
        if (caller != token.minting_account.owner) {                        
            return #err("Unauthorized: Only minting account can call this function..");
        }; 
        
        cancelTimer(autoTopupData.autoCyclesTopUpTimerId);
        autoTopupData.autoCyclesTopUpEnabled :=false;
        #ok("Automatic cycles topUp for archive canisters is now disabled");
    };

    /// Show the status of the auto fill up timer settings
    public shared func auto_topup_cycles_status() : async T.CanisterTypes.CanisterAutoTopUpDataResponse {
               
        let response:T.CanisterTypes.CanisterAutoTopUpDataResponse = {
            autoCyclesTopUpEnabled = autoTopupData.autoCyclesTopUpEnabled;
            autoCyclesTopUpMinutes = autoTopupData.autoCyclesTopUpMinutes;
            autoCyclesTopUpTimerId = autoTopupData.autoCyclesTopUpTimerId;
            autoCyclesTopUpOccuredNumberOfTimes = autoTopupData.autoCyclesTopUpOccuredNumberOfTimes;
        };

        response;
    };
    
    private func auto_topup_cycles_enable_internal(){
        cancelTimer(autoTopupData.autoCyclesTopUpTimerId);
                

        let timerSeconds:Nat = autoTopupData.autoCyclesTopUpMinutes * 60;
        autoTopupData.autoCyclesTopUpTimerId:= recurringTimer(#seconds timerSeconds,
         func () : async () {                     
                     await auto_topup_cycles_timer_tick();                     
                 }
        );

        autoTopupData.autoCyclesTopUpEnabled :=true;
    };

    private func auto_topup_cycles_timer_tick(): async (){
        
        let totalDynamicCanisters = List.size(archive_canisterIds.canisterIds);
        if (totalDynamicCanisters <= 0){
            return;
        };

        
        var balance = Cycles.balance();        
        let cyclesRequired = T.ConstantTypes.ARCHIVE_CYCLES_REQUIRED;        
        if (balance < T.ConstantTypes.TOKEN_CYCLES_TO_KEEP + (T.ConstantTypes.ARCHIVE_CYCLES_AUTOREFILL)) {            
            return;
        };
        

        let iter = List.toIter<Principal>(archive_canisterIds.canisterIds);
        
        for (item:Principal in iter){            
            let principalText:Text = Principal.toText(item);
            let archive:T.ArchiveTypes.ArchiveInterface = actor(principalText);
            let archiveCyclesBalance =  await archive.cycles_available();
            if (archiveCyclesBalance < cyclesRequired){
                let diff:Nat = T.ConstantTypes.ARCHIVE_CYCLES_AUTOREFILL-archiveCyclesBalance;
                if (balance > diff + T.ConstantTypes.TOKEN_CYCLES_TO_KEEP){
                    Cycles.add(T.ConstantTypes.ARCHIVE_CYCLES_AUTOREFILL);
                    await archive.deposit_cycles();
                    balance := Cycles.balance();   
                    autoTopupData.autoCyclesTopUpOccuredNumberOfTimes:= autoTopupData.autoCyclesTopUpOccuredNumberOfTimes + 1;
                };
            }
                            
        };
                
    };

    if (autoTopupData.autoCyclesTopUpEnabled == true){
        auto_topup_cycles_enable_internal();
    };

  
};
