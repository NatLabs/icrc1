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
    func shrink_subaccount(sub : Iter.Iter<Nat8>) : (Iter.Iter<Nat8>, Nat8) {
        let bytes = Blob.toArray(sub);
        var size = bytes.size();

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
        let suffix : [Nat8] = [size, 0x7f];

        Itertools.chain<Nat8>(
            sub_iter,
            suffix.vals(),
        );
    };

    public func encode({ owner; subaccount } : T.Account) : T.EncodedAccount {
        let owner_blob = Principal.toBlob(owner);

        switch (subaccount) {
            case (?subaccount) {
                if (subaccount == default_subaccount()) {
                    owner_blob;
                } else {
                    Blob.fromArray(
                        Iter.toArray(
                            Itertools.chain(
                                owner_blob.vals(),
                                encode_subaccount(subaccount),
                            ),
                        ),
                    );
                };
            };
            case (_) {
                owner_blob;
            };
        };
    };

    public func decode(encoded : T.EncodedAccount) : ?T.Account {
        let bytes = Blob.toArray(encoded);
        var size = bytes.size();

        if (bytes[size - 1] == 0x7f) {
            size -= 1;

            let sub_size = bytes[size - 1];

            if (sub_size == 0 or sub_size > 32) {
                return null;
            };

            size -= 1;
            let split_index = size - sub_size;

            ?{
                owner = Principal.fromBlob(
                    Blob.fromArray(
                        Array.slice(bytes, 0, split_index),
                    ),
                );

                subaccount = ?Blob.fromArray(
                    Array.slice(bytes, split_index, size),
                );
            }

        } else {
            ?{
                owner = Principal.fromBlob(encoded);
                subaccount = null;
            };
        };
    };
};
