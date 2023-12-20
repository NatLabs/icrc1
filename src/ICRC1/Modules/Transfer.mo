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

import Itertools "mo:itertools/Iter";
import StableBuffer "mo:StableBuffer/StableBuffer";
import STMap "mo:StableTrieMap";

import Account "Account";
import TransactionTypes = "../Types/Types.Transaction";
import TokenTypes "../Types/Types.Token";
import CommonTypes "../Types/Types.Common" ;
import Utils "Utils";

module {
    let { SB } = Utils;
    
    private type Balance = CommonTypes.Balance;
    private type Memo = TransactionTypes.Memo;
    private type TokenData = TokenTypes.TokenData;
    private type TransactionRequest = TransactionTypes.TransactionRequest;
    private type TransferError = TransactionTypes.TransferError;
        
    /// Checks if a transaction memo is valid
    private func validate_memo(memo : ?Memo) : Bool {
        switch (memo) {
            case (?bytes) {
                bytes.size() <= 32;
            };
            case (_) true;
        };
    };

    /// Checks if the `created_at_time` of a transfer request is before the accepted time range
    private func is_too_old(token : TokenData, created_at_time : Nat64) : Bool {
        let { permitted_drift; transaction_window } = token;

        let lower_bound = Time.now() - transaction_window - permitted_drift;
        Nat64.toNat(created_at_time) < lower_bound;
    };

    /// Checks if the `created_at_time` of a transfer request has not been reached yet relative to the canister's time.
    private func is_in_future(token : TokenData, created_at_time : Nat64) : Bool {
        let upper_bound = Time.now() + token.permitted_drift;
        Nat64.toNat(created_at_time) > upper_bound;
    };

    /// Checks if there is a duplicate transaction that matches the transfer request in the main canister.
    ///
    /// If a duplicate is found, the function returns an error (`#err`) with the duplicate transaction's index.
    private func deduplicate(token : TokenData, tx_req : TransactionRequest) : Result.Result<(), Nat> {
        // only deduplicates if created_at_time is set
        if (tx_req.created_at_time == null) {
            return #ok();
        };

        let { transactions = txs; archive } = token;

        var phantom_txs_size = 0;
        let phantom_txs = SB._clearedElemsToIter(txs);
        let current_txs = SB.vals(txs);

        let last_2000_txs = if (archive.stored_txs > 0) {
            phantom_txs_size := SB.capacity(txs) - SB.size(txs);
            Itertools.chain(phantom_txs, current_txs);
        } else {
            current_txs;
        };

        label for_loop for ((i, tx) in Itertools.enumerate(last_2000_txs)) {

            let is_duplicate = switch (tx_req.kind) {
                case (#mint) {
                    switch (tx.mint) {
                        case (?mint) {
                            ignore do ? {
                                if (is_too_old(token, mint.created_at_time!)) {
                                    break for_loop;
                                };
                            };

                            let mint_req : TransactionTypes.Mint = tx_req;

                            mint_req == mint;
                        };
                        case (_) false;
                    };
                };
                case (#burn) {
                    switch (tx.burn) {
                        case (?burn) {
                            ignore do ? {
                                if (is_too_old(token, burn.created_at_time!)) {
                                    break for_loop;
                                };
                            };
                            let burn_req : TransactionTypes.Burn = tx_req;

                            burn_req == burn;
                        };
                        case (_) false;
                    };
                };
                case (#transfer) {
                    switch (tx.transfer) {
                        case (?transfer) {
                            ignore do ? {
                                if (is_too_old(token, transfer.created_at_time!)) {
                                    break for_loop;
                                };
                            };

                            let transfer_req : TransactionTypes.Transfer = tx_req;

                            transfer_req == transfer;
                        };
                        case (_) false;
                    };
                };
            };

            if (is_duplicate) { return #err(tx.index) };
        };

        #ok();
    };

    /// Checks if a transfer fee is valid
    private func validate_fee(
        token : TokenData,
        opt_fee : ?Balance,
    ) : Bool {
        switch (opt_fee) {
            case (?tx_fee) {
                if (tx_fee < token.fee) { 
                    return false;
                };

                //make sure that not enormous fee is used by bad actor
                if (tx_fee > (token.fee * 10)) { 
                    return false;
                };

            };
            case (null) {
                //null is ok, becasue for real transaction the fee-value will be taken from 'token.fee', and not from 'tx_fee'
                return true;
            };
        };

        
        true;
    };

    /// Checks if a transfer request is valid
    public func validate_request(
        token : TokenData,
        tx_req : TransactionRequest,
    ) : Result.Result<(), TransferError> {

        if (tx_req.from == tx_req.to) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "The sender cannot have the same account as the recipient.";
                }),
            );
        };

        if (not Account.validate(tx_req.from)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for sender. "  # debug_show(tx_req.from);
                }),
            );
        };

        if (not Account.validate(tx_req.to)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for recipient " # debug_show(tx_req.to);
                }),
            );
        };

        if (not validate_memo(tx_req.memo)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Memo must not be more than 32 bytes";
                }),
            );
        };

        if (tx_req.amount == 0) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Amount must be greater than 0";
                }),
            );
        };

        if (tx_req.kind == #transfer or tx_req.kind ==#mint){
            if (tx_req.amount <= token.fee) {                
                return #err(
                    #GenericError({
                        error_code = 0;
                        message = "Amount must be greater than fee";
                    }),
                );
            };
        };

        switch (tx_req.kind) {
            case (#transfer) {
                if (not validate_fee(token, tx_req.fee)) {
                    return #err(
                        #BadFee {
                            expected_fee = token.fee;
                        },
                    );
                };

                var balance : Balance = Utils.get_balance(
                    token.accounts,
                    tx_req.encoded.from,
                );
                                                
                if (tx_req.amount + token.fee > balance) {                     
                    return #err(#InsufficientFunds { balance  });
                    
                };
            };

            case (#mint) {
                if (token.minting_allowed == false){
                    return #err(#GenericError({error_code = 0;message = "Minting not allowed";}));                    
                };

                let newAmount:Nat = Nat.max(token.minted_tokens - token.burned_tokens , 0);
                if (newAmount > token.max_supply){
                         
                    return #err(#GenericError({error_code = 0;message = "Total supply would be exceeded. Minting rejected.";}));
                };                
            };
			
            case (#burn) {
                if (tx_req.to == token.minting_account and tx_req.amount < token.min_burn_amount) {
                    return #err(
                        #BadBurn { min_burn_amount = token.min_burn_amount },
                    );
                };

                let balance : Balance = Utils.get_balance(
                    token.accounts,
                    tx_req.encoded.from,
                );

                if (balance < tx_req.amount) {
                    return #err(#InsufficientFunds { balance });
                };
            };
        };

        switch (tx_req.created_at_time) {
            case (null) {};
            case (?created_at_time) {

                if (is_too_old(token, created_at_time)) {
                    return #err(#TooOld);
                };

                if (is_in_future(token, created_at_time)) {
                    return #err(
                        #CreatedInFuture {
                            ledger_time = Nat64.fromNat(Int.abs(Time.now()));
                        },
                    );
                };

                switch (deduplicate(token, tx_req)) {
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
