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

        let sender_balance : T.Balance = U.get_balance(
            token.accounts,
            tx_req.encoded.from,
        );

        if (tx_req.amount > sender_balance) {
            return #err(#InsufficientFunds { balance = sender_balance });
        };

        switch (tx_req.created_at_time) {
            case (null) {};
            case (?created_at_time_nat64) {
                let created_at_time = Nat64.toNat(created_at_time_nat64);

                let { transaction_window; permitted_drift } = token;

                let accepted_range = {
                    start = Time.now() - transaction_window - permitted_drift;
                    end = Time.now() + permitted_drift;
                };

                if (created_at_time < accepted_range.start) {
                    return #err(#TooOld);
                };

                if (created_at_time > accepted_range.end) {
                    return #err(
                        #CreatedInFuture {
                            ledger_time = Nat64.fromNat(Int.abs(Time.now()));
                        },
                    );
                };

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
        };

        #ok();
    };

};
