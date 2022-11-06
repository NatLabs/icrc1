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

import ArrayModule "mo:array/Array";
import Itertools "mo:Itertools/Iter";
import StableBuffer "mo:StableBuffer/StableBuffer";
import STMap "mo:StableTrieMap";

import T "Types";

module {
    func shrink_subaccount(sub : Blob) : (Iter.Iter<Nat8>, Nat8) {
        let bytes = Blob.toArray(sub);
        var size = Nat8.fromNat(bytes.size());

        let iter = Itertools.skipWhile(
            bytes.vals(),
            func(byte : Nat8) : Bool {
                if (byte == 0x00) {
                    size -= 1;
                    return true;
                };

                false;
            },
        );

        (iter, size);
    };

    func encode_subaccount(sub : Blob) : Iter.Iter<Nat8> {

        let (sub_iter, size) = shrink_subaccount(sub);
        if (size == 0) {
            return Itertools.empty();
        };

        let suffix : [Nat8] = [size, 0x7f];

        Itertools.chain<Nat8>(
            sub_iter,
            suffix.vals(),
        );
    };

    /// Implementation of ICRC1's Textual representation of accounts [Encoding Standard](https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-1#encoding)
    public func encode({ owner; subaccount } : T.Account) : T.EncodedAccount {
        let owner_blob = Principal.toBlob(owner);

        switch (subaccount) {
            case (?subaccount) {
                Blob.fromArray(
                    Iter.toArray(
                        Itertools.chain(
                            owner_blob.vals(),
                            encode_subaccount(subaccount),
                        ),
                    ),
                );
            };
            case (_) {
                owner_blob;
            };
        };
    };

    /// Implementation of ICRC1's Textual representation of accounts [Decoding Standard](https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-1#decoding)
    public func decode(encoded : T.EncodedAccount) : ?T.Account {
        let bytes = Blob.toArray(encoded);
        var size = bytes.size();

        if (bytes[size - 1] == 0x7f) {
            size -= 1;

            let subaccount_size = Nat8.toNat(bytes[size - 1]);

            if (subaccount_size == 0 or subaccount_size > 32) {
                return null;
            };

            size -= 1;
            let split_index = size - subaccount_size;

            if (bytes[split_index] == 0) {
                return null;
            };

            let principal = Principal.fromBlob(
                Blob.fromArray(
                    ArrayModule.slice(bytes, 0, split_index),
                ),
            );

            let prefix_zeroes = Itertools.take(
                Iter.make(0 : Nat8),
                32 - subaccount_size,
            );

            let encoded_subaccount = Itertools.fromArraySlice(bytes, split_index, size);

            let subaccount = Blob.fromArray(
                Iter.toArray(
                    Itertools.chain(prefix_zeroes, encoded_subaccount),
                ),
            );

            ?{ owner = principal; subaccount = ?subaccount };
        } else {
            ?{
                owner = Principal.fromBlob(encoded);
                subaccount = null;
            };
        };
    };
};
