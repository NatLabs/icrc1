import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";

import Itertools "mo:Itertools/Iter";
import StableBuffer "mo:StableBuffer/StableBuffer";
import STMap "mo:StableTrieMap";

import T "Types";
import U "Utils";

module {
    let { SB } = U;

    public func subaccount(subaccount : ?T.Subaccount) : Bool {
        switch (subaccount) {
            case (?bytes) {
                bytes.size() == 32;
            };
            case (_) true;
        };
    };

    public func account(account : T.Account) : Bool {
        if (Principal.isAnonymous(account.owner)) {
            false;
        } else if (not subaccount(account.subaccount)) {
            false;
        } else {
            true;
        };
    };

    public func memo(memo : ?T.Memo) : Bool {
        switch (memo) {
            case (?bytes) {
                bytes.size() <= 32;
            };
            case (_) true;
        };
    };

    public func transaction_time(
        transaction_window : T.Timestamp,
        _created_at_time : ?T.Timestamp,
    ) : Result.Result<(), T.TimeError> {
        let now = Time.now();
        let created_at_time = switch (_created_at_time) {
            case (?time_in_nat64) {
                Nat64.toNat(time_in_nat64) : Int;
            };
            case (_) now;
        };

        let diff = now - created_at_time;

        if (created_at_time > now) {
            return #err(
                #CreatedInFuture {
                    ledger_time = Nat64.fromNat(Int.abs(now));
                },
            );
        } else if (diff > (Nat64.toNat(transaction_window) : Int)) {
            return #err(#TooOld);
        };

        #ok();
    };

    public func transfer(
        token : T.TokenData,
        tx_req : T.TransactionRequest,
    ) : Result.Result<(), T.TransferError> {

        if (tx_req.from == tx_req.to) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "The sender cannot have the same account as the recipient.";
                }),
            );
        };

        if (not account(tx_req.from)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for sender.";
                }),
            );
        };

        if (not account(tx_req.to)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for recipient";
                }),
            );
        };

        if (not memo(tx_req.memo)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Memo must not be more than 32 bytes";
                }),
            );
        };

        switch (transaction_time(token.transaction_window, tx_req.created_at_time)) {
            case (#err(errorMsg)) {
                return #err(errorMsg);
            };
            case (_) {};
        };

        let sender_balance : T.Balance = U.get_balance(
            token.accounts,
            tx_req.encoded.from,
        );

        if (tx_req.amount > sender_balance) {
            return #err(#InsufficientFunds { balance = sender_balance });
        };

        if (token.tx_deduplication) {
            switch (U.tx_has_duplicates(token, tx_req)) {
                case (#err(tx_index)) {

                    return #err(
                        #Duplicate {
                            duplicate_of = tx_index;
                        },
                    );
                };
                case (_) {};
            };
        };

        #ok();
    };

};
