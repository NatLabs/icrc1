import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Prelude "mo:base/Prelude";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Itertools "mo:itertools/Iter";
import Account "../../src/ICRC1/Account";
import ActorSpec "../utils/ActorSpec";
import Archive "../../src/ICRC1/Canisters/Archive";
import T "../../src/ICRC1/Types";
module {
    let {
        assertAllEqualWithDescription;
        assertTrue;
        assertFalse;
        assertAllTrue;
        describe;
        it;
        skip;
        pending;
        run;
    } = ActorSpec;


    


    public func test() : async ActorSpec.Group {
        let principal = Principal.fromText("prb4z-5pc7u-zdfqi-cgv7o-fdyqf-n6afm-xh6hz-v4bk4-kpg3y-rvgxf-iae");
        describe(
            "Account",
            [
                it(
                    "'null' subaccount",
                    do {
                        let account = {
                            owner = principal;
                            subaccount = null;
                        };

                        let encoded = Account.encode(account);
                        let decoded = Account.decode(encoded);
                        assertAllTrue([
                            encoded == Principal.toBlob(account.owner),
                            decoded == ?account,
                            Account.fromText("prb4z-5pc7u-zdfqi-cgv7o-fdyqf-n6afm-xh6hz-v4bk4-kpg3y-rvgxf-iae") == #ok(account),
                            Account.toText(account) == "prb4z-5pc7u-zdfqi-cgv7o-fdyqf-n6afm-xh6hz-v4bk4-kpg3y-rvgxf-iae",
                            Account.validate(account)
                        ]);
                    },                    
                ),
                it(
                    "subaccount with only zero bytes",
                    do {
                        let account = {
                            owner = principal;
                            subaccount = ?Blob.fromArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
                        };

                        let encoded = Account.encode(account);
                        let decoded = Account.decode(encoded);

                        assertAllTrue([
                            encoded == Principal.toBlob(account.owner),
                            decoded == ?{ account with subaccount = null },
                            Account.fromText("prb4z-5pc7u-zdfqi-cgv7o-fdyqf-n6afm-xh6hz-v4bk4-kpg3y-rvgxf-iae") == #ok{ account with subaccount = null },
                            Account.toText(account) == "prb4z-5pc7u-zdfqi-cgv7o-fdyqf-n6afm-xh6hz-v4bk4-kpg3y-rvgxf-iae",
                            Account.validate(account)
                        ]);
                    },
                ),                
                it(
                    "subaccount prefixed with zero bytes",
                    do {
                        let account = {
                            owner = principal;
                            subaccount = ?Blob.fromArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]);
                        };

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
                            Account.validate(account)
                        ]);
                    },
                ),                
                it(                    
                    "subaccount with zero bytes surrounded by non zero bytes",
                    do {
                        let account = {
                            owner = principal;
                            subaccount = ?Blob.fromArray([1, 2, 3, 4, 5, 6, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]);
                        };

                        let encoded = Account.encode(account);
                        let decoded = Account.decode(encoded);

                        let pricipal_iter = Principal.toBlob(account.owner).vals();

                        let valid_bytes : [Nat8] = [1, 2, 3, 4, 5, 6, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8];
                        let suffix_bytes : [Nat8] = [
                            32, // size of valid_bytes
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
                            Account.validate(account)
                        ]);
                    },
                ),
                it(                    
                    "subaccount with non zero bytes",
                    do {
                        let account = {
                            owner = principal;
                            subaccount = ?Blob.fromArray([123, 234, 156, 89, 92, 91, 42, 8, 15, 2, 20, 80, 60, 20, 30, 10, 78, 2, 3, 78, 89, 23, 52, 55, 1, 2, 3, 4, 5, 6, 7, 8]);
                        };

                        let encoded = Account.encode(account);
                        let decoded = Account.decode(encoded);

                        let pricipal_iter = Principal.toBlob(account.owner).vals();

                        let valid_bytes : [Nat8] = [123, 234, 156, 89, 92, 91, 42, 8, 15, 2, 20, 80, 60, 20, 30, 10, 78, 2, 3, 78, 89, 23, 52, 55, 1, 2, 3, 4, 5, 6, 7, 8];
                        let suffix_bytes : [Nat8] = [
                            32, // size of valid_bytes
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
                            Account.validate(account)
                        ]);
                    },
                ),
                it(
                    "should return false for invalid subaccount (length < 32)",
                    do {

                        var len = 0;
                        var is_valid = false;

                        label _loop while (len < 32){
                            let account = {
                                owner = principal;
                                subaccount = ?Blob.fromArray(Array.tabulate(len, Nat8.fromNat));
                            };

                            is_valid := is_valid or Account.validate(account) 
                                        or Account.validate_subaccount(account.subaccount);

                            if (is_valid) {
                                break _loop;
                            };

                            len += 1;
                        };
                        
                        not is_valid;
                    }
                ),

                it(
                    //Tests were added from this source: https://github.com/dfinity/ICRC-1/blob/main/ref/AccountTest.mo
                    "Tests for Account encode (Account.toText)",
                    do {
                         assertAllEqualWithDescription(
                            [
                                GetAssertParamForEncodeCheck(
                                    "iooej-vlrze-c5tme-tn7qt-vqe7z-7bsj5-ebxlc-hlzgs-lueo3-3yast-pae",
                                    ?[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                    "iooej-vlrze-c5tme-tn7qt-vqe7z-7bsj5-ebxlc-hlzgs-lueo3-3yast-pae",
                                    "EncodingTest1",
                                ),

                                GetAssertParamForEncodeCheck(
                                    "iooej-vlrze-c5tme-tn7qt-vqe7z-7bsj5-ebxlc-hlzgs-lueo3-3yast-pae",
                                    null,
                                    "iooej-vlrze-c5tme-tn7qt-vqe7z-7bsj5-ebxlc-hlzgs-lueo3-3yast-pae",
                                    "EncodingTest2",
                                ),

                                GetAssertParamForEncodeCheck(
                                    "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae",
                                    ?[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32],
                                    "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae-dfxgiyy.102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20",
                                    "EncodingTest3",
                                ),
                                    GetAssertParamForEncodeCheck(
                                    "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae",
                                    ?[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
                                    "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae-6cc627i.1",
                                    "EncodingTest4",
                                ),

                            ]
                         );                                                                                                            
                    }
                ),


                it(
                    //Tests were added from this source: https://github.com/dfinity/ICRC-1/blob/main/ref/AccountTest.mo
                    "Tests for Account decode (Account.fromText)",
                    do {
                         assertAllEqualWithDescription(
                            [
                                GetAssertParamForDecodeCheck(
                                    "iooej-vlrze-c5tme-tn7qt-vqe7z-7bsj5-ebxlc-hlzgs-lueo3-3yast-pae",
                                    #ok(defAccount("iooej-vlrze-c5tme-tn7qt-vqe7z-7bsj5-ebxlc-hlzgs-lueo3-3yast-pae")),                                    
                                    "DecodeTest1",
                                ),

                                  GetAssertParamForDecodeCheck(
                                      "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae-dfxgiyy.102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20",
                                        #ok(
                                            account("k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae", 
                                            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32])
                                        ),                                  
                                    "DecodeTest2",
                                ),

                                  GetAssertParamForDecodeCheck(
                                    "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae-6cc627i.1",
                                    #ok(
                                        account("k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae", 
                                        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
                                    ),
                                    "DecodeTest3",
                                ),

                                  GetAssertParamForDecodeCheck(
                                     "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae-6cc627i.01",
                                     #err(#not_canonical),
                                    "DecodeTest4",
                                ),

                                  GetAssertParamForDecodeCheck(
                                      "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae.1",
                                      #err(#bad_checksum),                                   
                                    "DecodeTest5",
                                ),

                                  GetAssertParamForDecodeCheck(
                                      "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae-6cc627j.1",
                                      #err(#bad_checksum),
                                    "DecodeTest6",
                                ),

                                  GetAssertParamForDecodeCheck(
                                       "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae-7cc627i.1",
                                       #err(#bad_checksum),
                                    "DecodeTest7",
                                ),

                                  GetAssertParamForDecodeCheck(
                                        "k2t6j-2nvnp-4zjm3-25dtz-6xhaa-c7boj-5gayf-oj3xs-i43lp-teztq-6ae-q6bn32y.",
                                        #err(#not_canonical),
                                    "DecodeTest8",
                                ),
                             
                            ]
                         );                                                                                                            
                    }
                )
            ]
        );

    };     

    func defAccount(owner : Text) : T.Account {
    { owner = Principal.fromText(owner); subaccount = null };
    };

    func account(owner : Text, subaccount : [Nat8]) : T.Account {
    {
        owner = Principal.fromText(owner);
        subaccount = ?Blob.fromArray(subaccount);
    };
    };
    func GetAssertParamForEncodeCheck(principalText:Text, subaccount : ?[Nat8], expectedText:Text, description:Text)
    : ActorSpec.AssertParam<Text,Text>{ 

        let encoded = ConvertAccountToText(principalText, subaccount);
        let returnValue :ActorSpec.AssertParam<Text, Text> =                 
        {                                                            
            actual = ?encoded;
            expected = ?expectedText;
            description= description;
            areEqual = func(A,E) {?E==?A};
        };       
        return returnValue;
    };


    func GetAssertParamForDecodeCheck(accountText:Text, expectedResult: Result.Result<T.Account, T.ParseError>, 
    description:Text)
    : ActorSpec.AssertParam<Result.Result<T.Account, T.ParseError>,Result.Result<T.Account, T.ParseError>>{ 

        let account = Account.fromText(accountText);
        
        let returnValue :ActorSpec.AssertParam<Result.Result<T.Account, T.ParseError>, Result.Result<T.Account, T.ParseError>> =                 
        {                                                            
            actual = ?account;
            expected = ?expectedResult;
            description= description;
            areEqual = func(A,E) {?E==?A};
        };       
        return returnValue;
    };



    func hexDigit(b : Nat8) : Nat8 {
        switch (b) {
            case (48 or 49 or 50 or 51 or 52 or 53 or 54 or 55 or 56 or 57) { b - 48 };
            case (65 or 66 or 67 or 68 or 69 or 70) { 10 + (b - 65) };
            case (97 or 98 or 99 or 100 or 101 or 102) { 10 + (b - 97) };
            case _ { Prelude.nyi() };
        };
    };

    func decodeHex(t : Text) : Blob {
        assert (t.size() % 2 == 0);
        let n = t.size() / 2;
        let h = Blob.toArray(Text.encodeUtf8(t));
        var b : [var Nat8] = Array.init(n, Nat8.fromNat(0));
        for (i in Iter.range(0, n - 1)) {
            b[i] := hexDigit(h[2 * i]) << 4 | hexDigit(h[2 * i + 1]);
        };
        Blob.fromArrayMut(b);
    };

    func ConvertAccountToText(principalText : Text, subaccount : ?[Nat8]):Text {
        
        Account.toText({
            owner = Principal.fromText(principalText);
            subaccount = Option.map(subaccount, Blob.fromArray);
        });
        
    };
};
