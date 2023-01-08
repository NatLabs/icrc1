import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";

import Itertools "mo:itertools/Iter";

import Account "../../src/ICRC1/Account";
import ActorSpec "../utils/ActorSpec";
import Archive "../../src/ICRC1/Canisters/Archive";

let {
    assertTrue;
    assertFalse;
    assertAllTrue;
    describe;
    it;
    skip;
    pending;
    run;
} = ActorSpec;

let principal = Principal.fromText("prb4z-5pc7u-zdfqi-cgv7o-fdyqf-n6afm-xh6hz-v4bk4-kpg3y-rvgxf-iae");

let account_with_null_subaccount = {
    owner = principal;
    subaccount = null;
};

let account_with_only_zero_bytes_in_subaccount = {
    owner = principal;
    subaccount = ?Blob.fromArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
};

let account_with_some_zero_bytes_in_subaccount = {
    owner = principal;
    subaccount = ?Blob.fromArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]);
};

let success = run([
    describe(
        "Account",
        [
            describe(
                "encode / decode Account",
                [
                    it(
                        "'null' subaccount",
                        do {
                            let account = account_with_null_subaccount;

                            let encoded = Account.encode(account_with_null_subaccount);
                            let decoded = Account.decode(encoded);
                            assertAllTrue([
                                encoded == Principal.toBlob(account.owner),
                                decoded == ?account,
                            ]);
                        },
                    ),

                    it(
                        "subaccount with only zero bytes",
                        do {
                            let account = account_with_only_zero_bytes_in_subaccount;

                            let encoded = Account.encode(account);
                            let decoded = Account.decode(encoded);

                            assertAllTrue([
                                encoded == Principal.toBlob(account.owner),
                                decoded == ?{ account with subaccount = null },
                            ]);
                        },
                    ),

                    it(
                        "subaccount with some zero bytes",
                        do {
                            let account = account_with_some_zero_bytes_in_subaccount;

                            let encoded = Account.encode(account);
                            let decoded = Account.decode(encoded);

                            let pricipal_iter = Principal.toBlob(account.owner).vals();

                            let valid_bytes : [Nat8] = [1, 2, 3, 4, 5, 6, 7, 8];
                            let suffix_bytes : [Nat8] = [
                                8, // size of valid_bytes
                                0x7f // ending tag
                            ];

                            let iter = Itertools.chain(
                                pricipal_iter,
                                Itertools.chain(
                                    valid_bytes.vals(),
                                    suffix_bytes.vals(),
                                ),
                            );

                            let expected_blob = Blob.fromArray(Iter.toArray(iter));

                            assertAllTrue([
                                encoded == expected_blob,
                                decoded == ?account,
                            ]);
                        },
                    ),
                    it(
                        "toText()",
                        do {
                            let account1 = account_with_null_subaccount;

                            let account2 = account_with_only_zero_bytes_in_subaccount;

                            let account3 = account_with_some_zero_bytes_in_subaccount;

                            assertAllTrue([
                                Account.toText(account1) == "E2FD3232C102357EE28F102B7C02B2E7F1F35E055C53CDBC46A6B95002",
                                Account.toText(account2) == "E2FD3232C102357EE28F102B7C02B2E7F1F35E055C53CDBC46A6B95002",
                                Account.toText(account3) == "E2FD3232C102357EE28F102B7C02B2E7F1F35E055C53CDBC46A6B950020102030405060708087F",
                            ]);
                        },
                    ),

                    it("fromText()", do {
                        let account1 = account_with_null_subaccount;

                        let account2 = account_with_only_zero_bytes_in_subaccount;

                        let account3 = account_with_some_zero_bytes_in_subaccount;

                        assertAllTrue([
                            Account.fromText("E2FD3232C102357EE28F102B7C02B2E7F1F35E055C53CDBC46A6B95002") == ?account1,
                            Account.fromText("E2FD3232C102357EE28F102B7C02B2E7F1F35E055C53CDBC46A6B95002") != ?account2,
                            Account.fromText("E2FD3232C102357EE28F102B7C02B2E7F1F35E055C53CDBC46A6B95002") == ?account1,
                            Account.fromText("E2FD3232C102357EE28F102B7C02B2E7F1F35E055C53CDBC46A6B950020102030405060708087F") == ?account3,
                        ]);
                    }),
                ],
            ),
        ],
    ),
]);

if (success == false) {
    Debug.trap("\1b[46;41mTests failed\1b[0m");
} else {
    Debug.print("\1b[23;42;3m Success!\1b[0m");
};
