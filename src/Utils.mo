import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";

import STMap "mo:StableTrieMap";
import SB "mo:StableBuffer/StableBuffer";

import T "Types";

module{
    public func init_metadata(args : T.InitArgs) : SB.StableBuffer<T.MetaDatum> {
        let metadata = SB.initPresized<T.MetaDatum>(4);
        SB.add(metadata, ("icrc1:fee", #Nat(args.fee)));
        SB.add(metadata, ("icrc1:name", #Text(args.name)));
        SB.add(metadata, ("icrc1:symbol", #Text(args.symbol)));
        SB.add(metadata, ("icrc1:decimals", #Nat(Nat8.toNat(args.decimals))));

        metadata
    };

    public let default_standard : T.SupportedStandard = {
       name = "ICRC-1";
       url = "https://github.com/dfinity/ICRC-1";
    };

    public let DAY_IN_NANO_SECONDS : T.Timestamp = 86_400_000_000_000;

    public func init_standards() : SB.StableBuffer<T.SupportedStandard> {
        let standards = SB.initPresized<T.SupportedStandard>(4);
        SB.add(standards, default_standard);
        
        standards
    };

    public func validate_subaccount(subaccount: ?T.Subaccount ) : Bool {
        switch(subaccount){
            case(?bytes) {
                bytes.size() == 32
            };
            case(_) true;
        };
    };

    public func validate_account(account: T.Account) : Bool {
        if (Principal.isAnonymous(account.owner)){
            false
        }else if (not validate_subaccount(account.subaccount)){
            false
        }else{
            true
        }
    };

    public func validate_memo(memo: ?T.Memo) : Bool{
        switch(memo){
            case(?bytes) {
                bytes.size() <= 32
            };
            case(_) true;
        };
    };

    // public func validate_transaction_time(transaction_window: T.Timestamp, _created_at_time: ?T.Timestamp): Result.Result<(), T.TimeError>{
    //     let now = Time.now();
    //     let created_at_time = Option.get(_created_at_time, now);

    //     let diff = now - created_at_time;
        
    //     if (created_at_time > now){
    //         return #err(
    //             #CreatedInFuture{
    //                 ledger_time : now;
    //             }
    //         );
    //     }else if (diff > transaction_window){
    //         return #err(#TooOld);
    //     };

    //     #ok()
    // };

    public func default_subaccount(): T.Subaccount {
        Blob.fromArray(
            Array.tabulate(32, func(_ : Nat) : Nat8 { 0 })
        )
    };

    public func new_subaccount_map(subaccount: ?T.Subaccount, balance: T.Balance): T.SubaccountStore {
        let map : T.SubaccountStore = STMap.new(Blob.equal, Blob.hash);
        STMap.put(
            map, 
            Option.get(subaccount, default_subaccount()), 
            balance
        );

        map
    };

    public func get_balance(accounts: T.AccountStore, req: T.Account ) : T.Balance {
        switch(STMap.get(accounts, req.owner)){
            case(?subaccounts){
                switch(req.subaccount){
                    case(?sub){
                        switch(STMap.get(subaccounts, sub)){
                            case(?balance){
                                balance
                            };
                            case(_) 0;
                        };
                    };
                    case(_) {
                        switch(STMap.get(subaccounts, default_subaccount())){
                            case(?balance){
                                balance
                            };
                            case(_) 0;
                        };
                    };
                };
            };
            case(_) 0;
        };
    };

    public func transfer_args_to_internal(args: T.TransferArgs, caller : Principal) : T.InternalTransferArgs{
        {
            sender = {
                owner = caller;
                subaccount = args.from_subaccount;
            };
            recipient = args.to;
            amount = args.amount;
            fee = args.fee;
            memo = args.memo;
            created_at_time = args.created_at_time;
        }
    };

    public func validate_transfer(accounts: T.AccountStore, args : T.InternalTransferArgs) : Result.Result<(), T.TransferError>{

        if (validate_account(args.sender)){
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for sender."
                })
            );
        };

        if (validate_account(args.recipient)){
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for recipient"
                })
            );
        };

        if (not validate_memo(args.memo)){
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Memo must not be more than 32 bytes"
                })
            );
        }; 

        // switch(validate_transaction_time(transaction_window, args.Collaterised)){
        //     case(#err(errorMsg)){
        //         return errorMsg;
        //     };
        //     case (_){};
        // };

        let sender_balance : T.Balance = get_balance(accounts, args.sender);
        
        // if (100 > sender_balance){
        //     return #err(#InsufficientFunds);
        // };

        #ok()
    };

    public func debug_icrc1_data(icrc1_data: T.InternalData){
        Debug.print("Name: " # icrc1_data.name);
        Debug.print("Symbol: " # icrc1_data.symbol);
        Debug.print("Decimals: " # debug_show icrc1_data.decimals);
        Debug.print("Fee: " # debug_show icrc1_data.fee);
        Debug.print("transaction_window: " # debug_show icrc1_data.transaction_window);
        Debug.print("minting_account: " # debug_show icrc1_data.minting_account);
        Debug.print("metadata: " # debug_show icrc1_data.metadata);
        Debug.print("supported_standards: " # debug_show icrc1_data.supported_standards);
        // Debug.print("accounts: " # debug_show icrc1_data.accounts);
        Debug.print("store_transactions: " # debug_show icrc1_data.store_transactions);
        Debug.print("transactions: " # debug_show icrc1_data.transactions);
    };
}