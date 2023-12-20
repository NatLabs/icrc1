import AccountTypes "Types.Account";
import CommonTypes "Types.Common";
import Principal "mo:base/Principal";
import Bool "mo:base/Bool";

module{

    public type CanisterStatsResponse ={
        name:Text;
        principal:Text;
        balance:CommonTypes.Balance;
    };

    public type CanisterAutoTopUpData = {
        var autoCyclesTopUpEnabled:Bool;
        var autoCyclesTopUpMinutes:Nat;
        var autoCyclesTopUpTimerId:Nat;
        var autoCyclesTopUpOccuredNumberOfTimes:Nat;
    };

    public type CanisterAutoTopUpDataResponse = {
        autoCyclesTopUpEnabled:Bool;
        autoCyclesTopUpMinutes:Nat;
        autoCyclesTopUpTimerId:Nat;
        autoCyclesTopUpOccuredNumberOfTimes:Nat;
    };

};