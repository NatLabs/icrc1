import AccountTypes "Types.Account";
import CommonTypes "Types.Common";
import Principal "mo:base/Principal";
import Bool "mo:base/Bool";

module{

    ///Response-type for the canister stats
    public type CanisterStatsResponse ={
        name:Text;
        principal:Text;
        balance:CommonTypes.Balance;
    };

    ///Stored as stable var in token.mo
    public type CanisterAutoTopUpData = {
        var autoCyclesTopUpEnabled:Bool;
        var autoCyclesTopUpMinutes:Nat;
        var autoCyclesTopUpTimerId:Nat;
        var autoCyclesTopUpOccuredNumberOfTimes:Nat;
    };

    ///Return-type for the 'auto_topup_cycles_status' function in token.mo
    public type CanisterAutoTopUpDataResponse = {
        autoCyclesTopUpEnabled:Bool;
        autoCyclesTopUpMinutes:Nat;
        autoCyclesTopUpTimerId:Nat;
        autoCyclesTopUpOccuredNumberOfTimes:Nat;
    };

};