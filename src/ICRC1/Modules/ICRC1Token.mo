import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Itertools "mo:itertools/Iter";
import StableTrieMap "mo:StableTrieMap";
import Cycles "mo:base/ExperimentalCycles";
import Bool "mo:base/Bool";
import Account "Account";
import Trie "mo:base/Trie";
import List "mo:base/List";

import Utils "Utils";
import Transfer "Transfer";
import Archive "../Canisters/Archive";
import T "../Types/Types.All";
import {ConstantTypes} = "../Types/Types.All";

/// The ICRC1 class with all the functions for creating an
/// ICRC1 token on the Internet Computer
module {
    let { SB } = Utils;

    private type Balance = T.Balance;

    private type Account = T.AccountTypes.Account;
    private type Subaccount = T.AccountTypes.Subaccount;
    private type AccountBalances = T.AccountTypes.AccountBalances;

    private type Transaction = T.TransactionTypes.Transaction;    
    private type TransferArgs = T.TransactionTypes.TransferArgs;
    private type Mint = T.TransactionTypes.Mint;
    private type BurnArgs = T.TransactionTypes.BurnArgs;
    private type TransactionRequest = T.TransactionTypes.TransactionRequest;
    private type TransferError = T.TransactionTypes.TransferError;
    private type TxIndex = T.TransactionTypes.TxIndex;
    private type GetTransactionsRequest = T.TransactionTypes.GetTransactionsRequest;
    private type GetTransactionsResponse = T.TransactionTypes.GetTransactionsResponse;
    private type QueryArchiveFn = T.TransactionTypes.QueryArchiveFn;
    private type TransactionRange = T.TransactionTypes.TransactionRange;
    private type ArchivedTransaction = T.TransactionTypes.ArchivedTransaction;
    private type TransferResult = T.TransactionTypes.TransferResult;

    private type SupportedStandard = T.TokenTypes.SupportedStandard;
    private type InitArgs = T.TokenTypes.InitArgs;
    private type TokenInitArgs = T.TokenTypes.TokenInitArgs;
    private type TokenData = T.TokenTypes.TokenData;
    private type MetaDatum = T.TokenTypes.MetaDatum;
    private type TokenInterface = T.TokenTypes.TokenInterface;
    private type RosettaInterface = T.TokenTypes.RosettaInterface;        
    private type FullInterface = T.TokenTypes.FullInterface;
    private type SetTextParameterResult = T.TokenTypes.SetTextParameterResult;
    private type SetBalanceParameterResult = T.TokenTypes.SetBalanceParameterResult;
    private type SetNat8ParameterResult = T.TokenTypes.SetNat8ParameterResult;
    private type SetAccountParameterResult = T.TokenTypes.SetAccountParameterResult;
    
    private type ArchiveInterface = T.ArchiveTypes.ArchiveInterface;
        
    /// Initialize a new ICRC-1 token
    public func init(args : T.TokenTypes.InitArgs) : T.TokenTypes.TokenData {
        
       
        //With this we map the fields of 'args' to direct variables.
        //So for example we do not need to use 'args.minting_account' and we can use 'minting_account' directly.
        let {
            name;
            symbol;
            decimals;
            fee;
            logo;
            minting_account;
            max_supply;
            initial_balances;
            min_burn_amount;
            minting_allowed;            
        } = args;

        var _burned_tokens = 0;        
        var permitted_drift = 60_000_000_000; // 1 minute
        var transaction_window = 86_400_000_000_000; //24 hours
           
        if (not Account.validate(minting_account)) {
            Debug.trap("minting_account is invalid");
        };

        let accounts : AccountBalances = StableTrieMap.new();

        var _minted_tokens = _burned_tokens;

        for ((i, (account, balance)) in Itertools.enumerate(initial_balances.vals())) {

            if (not Account.validate(account)) {
                Debug.trap(
                    "Invalid Account: Account at index " # debug_show i # " is invalid in 'initial_balances'",
                );
            };

            let encoded_account = Account.encode(account);

            StableTrieMap.put(
                accounts,        //Dictionnary to use
                Blob.equal,      //compare function
                Blob.hash,       //hash function
                encoded_account, //key
                balance,         //value
            );

            _minted_tokens += balance;
        };

        {
            var name = name;
            var symbol = symbol;
            var decimals = decimals;
            var fee = fee;
            var logo = logo;
            max_supply;
            var minted_tokens = _minted_tokens;
            var burned_tokens = _burned_tokens;
            var min_burn_amount = min_burn_amount;
            var minting_account = minting_account;
            minting_allowed;
            accounts;
            metadata = Utils.init_metadata(args);
            supported_standards = Utils.init_standards();
            transactions = SB.initPresized(ConstantTypes.MAX_TRANSACTIONS_IN_LEDGER);
            permitted_drift;
            transaction_window;
            archive = {
                var canister = actor ("aaaaa-aa");
                var stored_txs = 0;
            };
        };
    };

    /// Retrieve the name of the token
    public func name(token : TokenData) : Text {
        token.name;
    };

    /// Retrieve the symbol of the token
    public func symbol(token : TokenData) : Text {
        token.symbol;
    };

    /// Retrieve the number of decimals specified for the token
    public func decimals(token : TokenData) : Nat8 {
        token.decimals;
    };

    /// Retrieve the fee for each transfer
    public func fee(token : TokenData) : Balance {
        token.fee;
    };

    /// Retrieve the minimum burn amount for the token
    public func min_burn_amount(token : TokenData) : Balance {
        token.min_burn_amount;
    };

    /// Set the name of the token
    public func set_name(token : TokenData, name : Text, caller : Principal) : async* SetTextParameterResult {
        if (caller == token.minting_account.owner) {
            token.name := name;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting name only allowed via minting account.";
                },
            );
        };
        #Ok(token.name);
    };

    /// Set the symbol of the token
    public func set_symbol(token : TokenData, symbol : Text, caller : Principal) : async* SetTextParameterResult {
        if (caller == token.minting_account.owner) {
            token.symbol := symbol;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting symbol only allowed via minting account.";
                },
            );
        };
        #Ok(token.symbol);
    };

    /// Set the logo for the token
    public func set_logo(token : TokenData, logo : Text, caller : Principal) : async* SetTextParameterResult {
        if (caller == token.minting_account.owner) {
            token.logo := logo;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting logo only allowed via minting account.";
                },
            );
        };
        #Ok(token.logo);
    };

    /// Set the fee for each transfer
    public func set_fee(token : TokenData, fee : Nat, caller : Principal) : async* SetBalanceParameterResult {
        if (caller == token.minting_account.owner) {
            if (fee >= 10_000 and fee <= 1_000_000_000) {
                token.fee := fee;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: fee must be a value between 10_000 and 1_000_000_000.";
                    },
                );
            };
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting fee only allowed via minting account.";
                },
            );
        };
        #Ok(token.fee);
    };

    /// Set the number of decimals specified for the token
    public func set_decimals(token : TokenData, decimals : Nat8, caller : Principal) : async* SetNat8ParameterResult {
        if (caller == token.minting_account.owner) {
            if (decimals >= 2 and decimals <= 12) {
                token.decimals := decimals;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: decimals must be a value between 2 and 12.";
                    },
                );
            };      
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting decimals only allowed via minting account.";
                },
            );
        };
        #Ok(token.decimals);
    };

    /// Set the minimum burn amount
    public func set_min_burn_amount(token : TokenData, min_burn_amount : Nat, caller : Principal) : async* SetBalanceParameterResult {
        if (caller == token.minting_account.owner) {
            if (min_burn_amount >= 10_000 and min_burn_amount <= 1_000_000_000_000) {
                token.min_burn_amount := min_burn_amount;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: minimum burn amount must be a value between 10_000 and 1_000_000_000_000.";
                    },
                );
            };   
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting minimum burn amount only allowed via minting account.";
                },
            );
        };
        #Ok(token.min_burn_amount);
    };

    /// Retrieve all the metadata of the token
    public func metadata(token : TokenData) : [MetaDatum] {
        [
            ("icrc1:fee", #Nat(token.fee)),
            ("icrc1:name", #Text(token.name)),
            ("icrc1:symbol", #Text(token.symbol)),
            ("icrc1:decimals", #Nat(Nat8.toNat(token.decimals))),
            ("icrc1:minting_allowed", #Text(debug_show(token.minting_allowed)))
        ]
    };

    /// Returns the current archive canister
    public func get_archive(token : TokenData) : ArchiveInterface {
        token.archive.canister;
    };    

    /// Returns the total number of transactions in the archive
    public func get_archive_stored_txs(token : TokenData) : Nat {
        token.archive.stored_txs;
    };    

    /// Returns the total supply of circulating tokens
    public func total_supply(token : TokenData) : Balance {
        token.minted_tokens - token.burned_tokens;
    };

    /// Returns the total supply of minted tokens
    public func minted_supply(token : TokenData) : Balance {
        token.minted_tokens;
    };

    /// Returns the total supply of burned tokens
    public func burned_supply(token : TokenData) : Balance {
        token.burned_tokens;
    };

    /// Returns the maximum supply of tokens
    public func max_supply(token : TokenData) : Balance {
        token.max_supply;
    };

    /// Returns the account with the permission to mint tokens
    ///
    /// Note: **The minting account can only participate in minting
    /// and burning transactions, so any tokens sent to it will be
    /// considered burned.**

    public func minting_account(token : TokenData) : Account {
        token.minting_account;
    };

    /// Retrieve the balance of a given account
    public func balance_of({ accounts } : TokenData, account : Account) : Balance {
        let encoded_account = Account.encode(account);
        Utils.get_balance(accounts, encoded_account);
    };

    /// Returns an array of standards supported by this token
    public func supported_standards(token : TokenData) : [SupportedStandard] {
        SB.toArray(token.supported_standards);
    };

    /// Formats a float to a nat balance and applies the correct number of decimal places
    public func balance_from_float(token : TokenData, float : Float) : Balance {
        if (float <= 0) {
            return 0;
        };

        let float_with_decimals = float * (10 ** Float.fromInt(Nat8.toNat(token.decimals)));

        Int.abs(Float.toInt(float_with_decimals));
    };

    /// Transfers tokens from one account to another account (minting and burning included)    
    public func transfer(
        token : TokenData,
        args : TransferArgs,
        caller : Principal,
        archive_canisterIds: T.ArchiveTypes.ArchiveCanisterIds
    ) : async* TransferResult {

       
        let from = {
            owner = caller;
            subaccount = args.from_subaccount;
        };
        
        let tx_kind:T.TransactionTypes.TxKind = if (from == token.minting_account) {
           
            if (token.minting_allowed == false){                            
                return #Err(#GenericError {error_code = 401;message = "Error: Minting not allowed for this token.";});
            };

            if (caller != token.minting_account.owner)
            {                
                return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Minting not allowed.";
                },);
            };
            
            #mint
        } else if (args.to == token.minting_account) {
            #burn
        } else {                              
            #transfer
        };

        let tx_req = Utils.create_transfer_req(args, caller, tx_kind);

        switch (Transfer.validate_request(token, tx_req)) {
            case (#err(errorType)) {                
                return #Err(errorType);
            };
            case (#ok(_)) {};
        };

        let { encoded; amount } = tx_req; 

        // process transaction
        switch(tx_req.kind){
            case(#mint){
                Utils.mint_balance(token, encoded.to, amount);
            };
            case(#burn){
                Utils.burn_balance(token, encoded.from, amount);
            };
            case(#transfer){
                                                  
                Utils.transfer_balance(token, tx_req);

                // burn fee
                Utils.burn_balance(token, encoded.from, token.fee);
            };
        };
        
        // store transaction
        let index = SB.size(token.transactions) + token.archive.stored_txs;
        let tx = Utils.req_to_tx(tx_req, index);
        SB.add(token.transactions, tx);

        // transfer transaction to archive if necessary
        let result:(Bool,?Principal) = await* update_canister(token);
        if (result.0 == true){
            switch(result.1){
                case (?principal) ignore updateCanisterIdList(principal,archive_canisterIds );
                case (null) {};
            }
        };
                
        #Ok(tx.index);
    };

    /// Helper function to mint tokens with minimum args
    public func mint(token : TokenData, args : Mint, caller : Principal,  
                    archive_canisterIds: T.ArchiveTypes.ArchiveCanisterIds) : async* TransferResult {

        if (token.minting_allowed == false){            
            return #Err(#GenericError {error_code = 401;message = "Error: Minting not allowed for this token.";});
        };
        if (caller == token.minting_account.owner) {            
            let transfer_args : TransferArgs = {
                args with from = token.minting_account;
                from_subaccount = null;
                fee = null;
            };
            
            await* transfer(token, transfer_args, caller, archive_canisterIds);            
            
        } else {            
            return #Err(#GenericError {error_code = 401;message = "Unauthorized: Minting not allowed.";},);
        };        													        
    };

    /// Helper function to burn tokens with minimum args
    public func burn(token : TokenData, args : BurnArgs, caller : Principal,
                archive_canisterIds: T.ArchiveTypes.ArchiveCanisterIds) : async* TransferResult {

        let transfer_args : TransferArgs = {
            args with to = token.minting_account;
            fee = null;
        };

        await* transfer(token, transfer_args, caller, archive_canisterIds);
    };

    /// Returns the total number of transactions that have been processed by the given token.
    public func total_transactions(token : TokenData) : Nat {
        let { archive; transactions } = token;
        archive.stored_txs + SB.size(transactions);
    };

    /// Retrieves the transaction specified by the given `tx_index`
    public func get_transaction(token : TokenData, tx_index : TxIndex) : async* ?Transaction {
        let { archive; transactions } = token;

        let archived_txs = archive.stored_txs;

        if (tx_index < archive.stored_txs) {
            await archive.canister.get_transaction(tx_index);
        } else {
            let local_tx_index = (tx_index - archive.stored_txs) : Nat;
            SB.getOpt(token.transactions, local_tx_index);
        };
    };

    /// Retrieves the transactions specified by the given range
    public func get_transactions(token : TokenData, req : GetTransactionsRequest) : GetTransactionsResponse {
        let { archive; transactions } = token;

        var first_index = 0xFFFF_FFFF_FFFF_FFFF; // returned if no transactions are found

        let req_end = req.start + req.length;
        let tx_end = archive.stored_txs + SB.size(transactions);

        var txs_in_canister: [Transaction] = [];
        
        if (req.start < tx_end and req_end >= archive.stored_txs) {
            first_index := Nat.max(req.start, archive.stored_txs);
            let tx_start_index = (first_index - archive.stored_txs) : Nat;

            txs_in_canister:= SB.slice(transactions, tx_start_index, req.length);
        };

        let archived_range = if (req.start < archive.stored_txs) {
            {
                start = req.start;
                end = Nat.min(
                    archive.stored_txs,
                    (req.start + req.length) : Nat,
                );
            };
        } else {
            { start = 0; end = 0 };
        };

        let txs_in_archive = (archived_range.end - archived_range.start) : Nat;

        let size = Utils.div_ceil(txs_in_archive, ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST);

        let archived_transactions = Array.tabulate(
            size,
            func(i : Nat) : ArchivedTransaction {
                let offset = i * ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST;
                let start = offset + archived_range.start;
                let length = Nat.min(
                    ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST,
                    archived_range.end - start,
                );

                let callback = token.archive.canister.get_transactions;

                { start; length; callback };
            },
        );

        {
            log_length = txs_in_archive + txs_in_canister.size();
            first_index;
            transactions = txs_in_canister;
            archived_transactions;
        };
    };

    /// Returns the list of the token-holders - with their balances included
    public func get_holders(token : TokenData, index:?Nat, count:?Nat): [T.AccountTypes.AccountBalanceInfo]{
           
        let size:Nat = token.accounts._size;    
        let indexValue:Nat = switch(index)    {
            case (?index) index;
            case (null) 0;
        };

        let countValue:Nat = switch(count)    {
            case (?count) count;
            case (null) size;
        };

        if (indexValue >= size){
            return [];
        };
        let maxNumbersOfHoldersToReturn:Nat = 5000;
        var countToUse:Nat = Nat.min(Nat.min(countValue,size-indexValue), maxNumbersOfHoldersToReturn);
        let defaultAccount:T.AccountTypes.Account = {owner = Principal.fromText("aaaaa-aa"); subaccount = null };
        var iter = Trie.iter(token.accounts.trie);
        
        //Because of reverse order:
        let revIndex:Nat = size - (indexValue + countToUse);

        iter := Itertools.skip(iter, revIndex);
        iter := Itertools.take(iter, countToUse);
        

        var resultList: List.List<T.AccountTypes.AccountBalanceInfo> = List.nil<T.AccountTypes.AccountBalanceInfo>();
        var resultIter = Iter.fromList<T.AccountTypes.AccountBalanceInfo>(resultList);

               
        for ((k:Blob,v:T.CommonTypes.Balance) in iter) {                                    
            let account:?T.AccountTypes.Account = Account.decode(k);            
            let balance:Nat = v;            
            let newItem:T.AccountTypes.AccountBalanceInfo = { account = Option.get(account, defaultAccount); balance = balance};
            resultIter := Itertools.prepend<T.AccountTypes.AccountBalanceInfo>(newItem,resultIter);            
        };
        
        return Iter.toArray<T.AccountTypes.AccountBalanceInfo>(resultIter);        
    };


    /// Get the canister's cycle balance information for all the created archive canisters.
    /// If this method was called from minting-owner account then also the canister-id's are included.
    public func all_canister_stats(hidePrincipal:Bool, 
        mainTokenPrincipal:Principal,mainTokenBalance:Balance, archive_canisterIds: T.ArchiveTypes.ArchiveCanisterIds )
        : async* [T.CanisterTypes.CanisterStatsResponse]{
      
       var showFullInfo = false;
       if (hidePrincipal == false) {  
        showFullInfo :=true;
       };

       var returnList:List.List<T.CanisterTypes.CanisterStatsResponse> = List.nil<T.CanisterTypes.CanisterStatsResponse>();
       
       let itemForMainToken:T.CanisterTypes.CanisterStatsResponse = {
            name = "Main token";
            principal = Principal.toText(mainTokenPrincipal);
            balance = mainTokenBalance;
       };
       returnList := List.push(itemForMainToken, returnList);
       
       
       let iter = List.toIter<Principal>(archive_canisterIds.canisterIds);
       var counter = 1;
       for (item:Principal in iter){            
            let principalText:Text = Principal.toText(item);
            let archive:T.ArchiveTypes.ArchiveInterface = actor(principalText);
            let archiveCyclesBalance =  await archive.cycles_available();

            let newItem:T.CanisterTypes.CanisterStatsResponse = {
                name = "Archive canister No:" #debug_show(counter);
                principal =  switch (showFullInfo) {
                    case (true) Principal.toText(item);
                    case (false) "<Hidden>";
                };
                balance = archiveCyclesBalance;
            };
            returnList := List.push(newItem, returnList);
            counter :=counter + 1;            
       };
       returnList :=List.reverse(returnList);

       return List.toArray<T.CanisterTypes.CanisterStatsResponse>(returnList);
    };

    // Updates the token's data and manages the transactions
    //
    // **added at the end of any function that creates a new transaction**
    func update_canister(token : TokenData) : async* (Bool,?Principal) {
        let txs_size = SB.size(token.transactions);
        
        if (txs_size >= ConstantTypes.MAX_TRANSACTIONS_IN_LEDGER) {
            return  await* append_transactions(token);
        };

        return (false, null);
    };

    // Moves the transactions from the ICRC1 canister to the archive canister
    // and returns a boolean that indicates the success of the data transfer
    func append_transactions(token : TokenData) : async* (Bool,?Principal) {
        let { archive; transactions } = token;

        var newArchiveCanisterId : ?Principal = null;
        var canisterWasAdded = false;

        if (archive.stored_txs == 0) {
            
            Cycles.add(ConstantTypes.ARCHIVE_CANISTERS_MINIMUM_CYCLES_REQUIRED);
            archive.canister := await Archive.Archive();
            newArchiveCanisterId := Option.make(await archive.canister.init());
            canisterWasAdded :=true;

        } else { 
            let add = await* should_add_archive(token);
            if (add == 1) {
                newArchiveCanisterId := Option.make(await* add_additional_archive(token));
                canisterWasAdded :=true;
            };
        };

        let res = await archive.canister.append_transactions(
            SB.toArray(transactions),
        );

        switch (res) {
            case (#ok(_)) {
                archive.stored_txs += SB.size(transactions);
                SB.clear(transactions);
            };
            case (#err(_)) {};
        };

        return (canisterWasAdded, newArchiveCanisterId);
    };

    /// Here it is decided if additional archive canister should be created
    func should_add_archive(token : TokenData) : async* Nat {
        
        let { archive } = token;
        let total_used = await archive.canister.total_used();
        let remaining_capacity = await archive.canister.remaining_capacity();

        if ( total_used >= remaining_capacity ) {
            return 1;
        };

        0;
    };    

    /// Creates a new archive canister
    func add_additional_archive(token : TokenData) : async* Principal {
        let { archive; transactions } = token;

        let oldCanister = archive.canister;
        let old_total_tx : Nat = await oldCanister.total_transactions();
        let old_first_tx : Nat = await oldCanister.get_first_tx();
        let old_last_tx : Nat = old_first_tx + old_total_tx - 1;
                
        //Add cycles, because we are creating new canister
        Cycles.add(T.ConstantTypes.ARCHIVE_CANISTERS_MINIMUM_CYCLES_REQUIRED);                
        let newCanister = await Archive.Archive();
        let canisterId = await newCanister.init();
        
        let res1 = await oldCanister.set_last_tx(old_last_tx);        
        let res2 = await oldCanister.set_next_archive(newCanister);
        let res3 = await newCanister.set_prev_archive(oldCanister);

        let res4 = await newCanister.set_first_tx(old_last_tx + 1);

        archive.canister := newCanister;
        return canisterId;
    };

    private func updateCanisterIdList(principal: Principal, archive_canisterIds: T.ArchiveTypes.ArchiveCanisterIds): async (){

        if (ArchivePrincipalIdsInList(principal,archive_canisterIds) == false){
            archive_canisterIds.canisterIds := List.push<Principal>(principal, archive_canisterIds.canisterIds);                    
        };
    
    };

    private func ArchivePrincipalIdsInList(principal : Principal, archive_canisterIds: T.ArchiveTypes.ArchiveCanisterIds): Bool{
  
        if (List.size(archive_canisterIds.canisterIds) <=0){
            return false;
        };

        func listFindFunc(x : Principal) : Bool {
            x  == principal;
        };

        return List.some<Principal>(archive_canisterIds.canisterIds, listFindFunc);
    };
};
