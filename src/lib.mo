import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";

import STMap "mo:StableTrieMap";
import SB "mo:StableBuffer/StableBuffer";

import T "Types";
import U "Utils";

module ICRC1 {
    public type StableTrieMap<K, V> = STMap.StableTrieMap<K, V>;
    public type StableBuffer<T> = SB.StableBuffer<T>;

    public type Account = T.Account;
    public type Subaccount = T.Subaccount;
    public type AccountStore = T.AccountStore;

    public type Transaction = T.Transaction;
    public type Balance = T.Balance;
    public type TransferArgs = T.TransferArgs; 
    public type TransferError = T.TransferError; 

    public type SupportedStandard = T.SupportedStandard;

    public type InitArgs = T.InitArgs;
    public type InternalData = T.InternalData;
    public type MetaDatum = T.MetaDatum;
    public type TxLog = T.TxLog;

    /// Initialize a new ICRC-1 token
    public func init(args: InitArgs) : InternalData{
        let {
            name;
            symbol;
            decimals;
            fee;
            minting_account;
            max_supply;
            store_transactions;
        } = args;

        if (not U.validate_account(minting_account)){
            Debug.trap("minting_account is invalid");
        };

        if (max_supply < 10 ** Nat8.toNat(decimals)){
            Debug.trap("max_supply >= 1");
        };

        let accounts : AccountStore = STMap.new(Principal.equal, Principal.hash);
        STMap.put(
            accounts, 
            minting_account.owner, 
            U.new_subaccount_map(
                minting_account.subaccount, 
                max_supply
            )
        );

        {
            var name = name;
            var symbol = symbol;
            decimals;
            var fee = fee;
            max_supply;
            minting_account;
            accounts;
            metadata = U.init_metadata(args);
            supported_standards = U.init_standards();
            store_transactions;
            transactions = SB.init();
            transaction_window = U.DAY_IN_NANO_SECONDS;
        }
    };

    public func name(token: InternalData) : Text{
        token.name
    };

    public func symbol(token: InternalData) : Text{
        token.symbol
    };

    public func decimals({ decimals }: InternalData) : Nat8{
        decimals
    };

    public func fee(token: InternalData) : Balance {
        token.fee
    };

    public func metadata(token: InternalData) : [MetaDatum] {
        SB.toArray(token.metadata)
    };

    public func total_supply(token: InternalData) : Balance {
        let { 
            max_supply; 
            accounts; 
            minting_account;
        } = token;

        max_supply - U.get_balance(accounts, minting_account)
    };

    public func minting_account(token: InternalData) : Account {
        token.minting_account
    };

    public func balance_of({accounts}: InternalData, req: Account) : Balance {
        U.get_balance(accounts, req)
    };

    public func supported_standards(token: InternalData) : [SupportedStandard] {
        SB.toArray(token.supported_standards)
    };

    /// Initialize a new ICRC-1 from pre-existing token data
    // public func fromICRC1(args: InitArgs) : InternalData {
        
    //     var accounts : AccountStore =  STMap.new(Principal.equal, Principal.hash);
    //     var max_supply = args.max_supply;

    //     let minting_account = switch(args.minting_account){
    //         case(?main) {
    //             if (not U.validate_subaccount(main.subaccount)){
    //                 Debug.trap("minting_account has an invalid Subaccount");
    //             };

    //             main
    //         };
    //         case (_) {
    //             if (not U.validate_subaccount(args.canister.subaccount)){
    //                 Debug.trap("canister has an invalid Subaccount");
    //             };

    //             args.canister
    //         };
    //     };

    //     let minting_subaccount = switch(minting_account.subaccount){
    //         case(?sub) sub;
    //         case(_) U.default_subaccount();
    //     };

    //     STMap.put(
    //         accounts, 
    //         minting_account.owner, 
    //         U.new_subaccount_map(
    //             minting_account.subaccount, 
    //             args.total_supply
    //         )
    //     );

    //     switch(args.accounts){
    //         case (?init_accounts){
    //             if (init_accounts.size() > 0){
    //                 total_supply:= 0;
    //             };

    //             for ((owner, subs) in init_accounts.vals()){
    //                 if (Principal.isAnonymous(owner)){
    //                     Debug.trap("Anonymous Principal (2vxsx-fae) is not allowed");
    //                 };

    //                 let sub_map : T.SubaccountStore = STMap.new(Blob.equal, Blob.hash);

    //                 for ((sub, balance) in subs.vals()){
    //                     if (U.validate_subaccount(?sub)){
    //                         STMap.put(sub_map, sub, balance);
    //                     }else{
    //                         Debug.trap("Invalid Subaccount ");
    //                     };

    //                     total_supply += balance;
    //                 };

    //                 STMap.put(accounts, owner, sub_map);
    //             };
    //         };
    //         case (_){};
    //     };

    //     let metadata = switch(args.metadata){
    //         case(?data){
    //             SB.fromArray<MetaDatum>(data)
    //         };
    //         case(_){
    //             SB.initPresized<MetaDatum>(4);
    //         };
    //     };

    //     SB.add(metadata, ("icrc1:fee", #Nat(args.fee)));
    //     SB.add(metadata, ("icrc1:name", #Text(args.name)));
    //     SB.add(metadata, ("icrc1:symbol", #Text(args.symbol)));
    //     SB.add(metadata, ("icrc1:decimals", #Nat(Nat8.toNat(args.decimals))));
        
    //     let supported_standards = switch(args.supported_standards){
    //         case(?standards){
    //             SB.fromArray<SupportedStandard>(standards)
    //         };
    //         case(_){
    //             SB.initPresized<SupportedStandard>(1);
    //         };
    //     };

    //     let default_standard : SupportedStandard = {
    //         name = "ICRC-1";
    //         url = "https://github.com/dfinity/ICRC-1";
    //     };
        
    //     SB.add(supported_standards, default_standard);
        
    //     let store_transactions = switch(args.store_transactions){
    //         case (?val) val == true;
    //         case (_) false;
    //     };

    //     let transactions : ?T.TxLog = switch((store_transactions, args.transactions)){
    //         case (true, ?txs) ?SB.fromArray(txs);
    //         case (_) null;
    //     };

    //     let transaction_window = switch(args.transaction_window){
    //         case(?seconds){
    //             Nat64.max(seconds, 60) * 1_000_000_000
    //         };
    //         case(_){
    //             (24 * 60 * 60 * 1_000_000_000) : Nat64
    //         };
    //     };

    //     {
    //         var name = args.name;
    //         var symbol = args.symbol;
    //         var fee = args.fee;
    //         var total_supply = total_supply;

    //         decimals = args.decimals;
    //         var controller = args.controller;
    //         canister = args.canister;
    //         accounts;
    //         metadata;
    //         minting_account;
    //         supported_standards;
    //         transaction_window;
    //         store_transactions;
    //         transactions;
    //     }
    // };

    public func transfer(token: InternalData, args: TransferArgs, caller : Principal) : Result.Result<(), TransferError> { 
        let {
            accounts; 
            minting_account; 
            transaction_window
        } = token; 

        let internal_args = U.transfer_args_to_internal(args, caller);

        let { sender; recipient } = internal_args;

        if (sender == minting_account or recipient == minting_account){
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "minting_account can only participate in minting and burning transactions not transfers"
                })
            )
        };

        switch(args.fee){
            case(?fee){
                if (not (token.fee == fee)){
                    return #err(
                        #BadFee{
                            expected_fee = token.fee;
                        }
                    );
                }
            };
            case(_){
                if (not (token.fee == 0)){
                    return #err(
                        #BadFee{
                            expected_fee = token.fee;
                        }
                    );
                }
            };
        };
        
        switch(U.validate_transfer(accounts, internal_args)){
            case(#err(errorType)){
                return #err(errorType);
            };
            case(#ok(_)){};
        };
        
        #ok()
    };

};
