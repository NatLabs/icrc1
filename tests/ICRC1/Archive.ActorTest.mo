import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import EC "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import Bool "mo:base/Bool";

import Archive "../../src/ICRC1/Canisters/Archive";
import T "../../src/ICRC1/Types";

import ActorSpec "../utils/ActorSpec";

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

    func new_tx(i : Nat) : T.Transaction {
        {
            kind = "";
            mint = null;
            burn = null;
            transfer = null;
            index = i;
            timestamp = Nat64.fromNat(i);
        };
    };

    // [start, end)
    func txs_range(start : Nat, end : Nat) : [T.Transaction] {
        Array.tabulate(
            (end - start) : Nat,
            func(i : Nat) : T.Transaction {
                new_tx(start + i);
            },
        );
    };

    func new_txs(length : Nat) : [T.Transaction] {
        txs_range(0, length);
    };

    let TC = 1_000_000_000_000;
    let CREATE_CANISTER = 100_000_000_000;

    func create_canister_and_add_cycles(n : Float) {
        EC.add(
            CREATE_CANISTER + Int.abs(Float.toInt(n * 1_000_000_000_000)),
        );
    };
 

    func GetAssertParamForTransactionCheck(actualTransaction:?T.Transaction, index:?Nat, description:Text)
    : ActorSpec.AssertParam<T.Transaction,T.Transaction>{ 

        let returnValue :ActorSpec.AssertParam<T.Transaction,T.Transaction> =                 
        {                                                            
            actual = actualTransaction;
            expected = switch(index){
                case (?a) { ?new_tx(a)};
                case null {null};
            };
            description= "Transaction at index: " # description;
            areEqual =  func(A,E) {?E==?A};
        };       
        return returnValue;
    };

        func GetAssertParamForTransactionsCheck(actualTransactions:[T.Transaction], fromTo:?(fromIndex:Nat, toIndex:Nat), description:Text)
    : ActorSpec.AssertParam<[T.Transaction],[T.Transaction]>{ 

        let returnValue :ActorSpec.AssertParam<[T.Transaction],[T.Transaction]> =                 
        {                                                            
            actual = ?actualTransactions;
            expected = switch(fromTo){
                case (?a) { ?txs_range(a.0, a.1)};
                case null {null};
            };
            description= "Transactions at from-to: " # description;
            areEqual =  func(A,E) {?E==?A};
        };       
        return returnValue;
    };


 

    public func test() : async ActorSpec.Group {
        describe(
            "Archive Canister",
            [
                it(
                    "append_transactions()",
                    do {
                        create_canister_and_add_cycles(0.1);
                        let archive = await Archive.Archive();

                        let txs = new_txs(500);

                        assertAllTrue([
                            (await archive.total_transactions()) == 0,
                            (await archive.append_transactions(txs)) == #ok(),
                            (await archive.total_transactions()) == 500,
                        ]);
                    },
                ),
                it(
                    "get_transaction() - with 3555 transactions",
                    do {
                        Debug.print("Started 'get_transaction() - with 3555 transactions'");
                        create_canister_and_add_cycles(0.1);
                        let archive = await Archive.Archive();
                        let txs = new_txs(3555);
                        ignore await archive.append_transactions(txs);
                      
                        var returnResult = true;
                        let firstResult = assertAllEqualWithDescription<Nat,Nat>([
                            
                            {                                                            
                             actual = Option.make(await archive.total_transactions());
                             expected = ?3555;
                             description= "total transactions == 3555" # debug_show(3555);
                             areEqual =  func(A,E) {A==E}; 
                            }
                        ]);

                        returnResult := returnResult and firstResult;
                                               
                        let secondResult = assertAllEqualWithDescription(
                            [
                                GetAssertParamForTransactionCheck(await archive.get_transaction(0), ?0, "0"),                                                                
                                GetAssertParamForTransactionCheck(await archive.get_transaction(999), ?999, "999"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(1000), ?1000, "1000"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(1234), ?1234, "1234"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(2829), ?2829, "2829"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(3554), ?3554, "3554"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(3555), null, "3555"),                                                           
                                GetAssertParamForTransactionCheck(await archive.get_transaction(999999), null, "999999")                                
                            ]
                        );
                        
                        returnResult := returnResult and secondResult;
                        returnResult;
                    },
                ),
                           
                it(
                    "get_transaction() - with 55000 transactions",
                    do {
                        Debug.print("Startedclear
                         'get_transaction() - with 55000 transactions'");
                        create_canister_and_add_cycles(0.1);
                        let archive = await Archive.Archive();                        
                        let txs = new_txs(55000);
                        ignore await archive.append_transactions(txs);
                       
                        var returnResult = true;
                        let firstResult = assertAllEqualWithDescription<Nat,Nat>([
                            
                            {                                                            
                             actual = Option.make(await archive.total_transactions());
                             expected = ?55000;
                             description= "total transactions == 55000";
                             areEqual =  func(A,E) {A==E}; 
                            }
                        ]);

                        returnResult := returnResult and firstResult;
                                               
                        let secondResult = assertAllEqualWithDescription(
                            [
                                GetAssertParamForTransactionCheck(await archive.get_transaction(0), ?0, "0"),                                                                
                                GetAssertParamForTransactionCheck(await archive.get_transaction(999), ?999, "999"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(1000), ?1000, "1000"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(1234), ?1234, "1234"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(2829), ?2829, "2829"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(3554), ?3554, "3554"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(3555), ?3555, "3555"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(9000), ?9000, "9000"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(15000), ?15000, "15000"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(25000), ?25000, "25000"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(54000), ?54000, "54000"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(54999), ?54999, "54999"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(55000), null, "55000"),
                                GetAssertParamForTransactionCheck(await archive.get_transaction(55001), null, "55001"),                                
                                GetAssertParamForTransactionCheck(await archive.get_transaction(999999), null, "999999")                                
                            ]
                        );
                        
                        returnResult := returnResult and secondResult;
                        returnResult;                  
                    },
                ),
                it(
                    "get_transactions()",
                    do {

                        create_canister_and_add_cycles(0.1);
                        let archive = await Archive.Archive();

                        let txs = new_txs(9000);

                        let res = await archive.append_transactions(txs);

                        // let tx_range = await archive.get_transactions({
                        //     start = 3251;
                        //     length = 2000;
                        // });

                        /*
                        //let transTest = await archive.get_transactions({ start = 3251; length = 2000 });
                        let transTest = await archive.get_transactions({ start = 3251; length = 1000 });
                        //let transTest = await archive.get_transactions({ start = 980; length = 100 });
                        let transCount = transTest.transactions.size();
                        Debug.print("Array size: " # debug_show(transCount));
                        */

                        // assertAllTrue([
                        //     res == #ok(),
                        //     (await archive.total_transactions()) == 5000,
                        //     (await archive.get_transactions({ start = 0; length = 100 })).transactions == txs_range(0, 100),
                        //     (await archive.get_transactions({ start = 225; length = 100 })).transactions == txs_range(225, 325),
                        //     (await archive.get_transactions({ start = 225; length = 1200 })).transactions == txs_range(225, 1425),
                        //     //(await archive.get_transactions({ start = 980; length = 100 })).transactions == txs_range(980, 1080),
                        //     //(await archive.get_transactions({ start = 3251; length = 2000 })).transactions == txs_range(3251, 4999),
                        // ]);


                          var returnResult = true;
                        let firstResult = assertAllEqualWithDescription<Nat,Nat>([
                            
                            {                                                            
                             actual = Option.make(await archive.total_transactions());
                             expected = ?9000;
                             description= "total transactions == 9000";
                             areEqual =  func(A,E) {A==E}; 
                            }
                        ]);

                        returnResult := returnResult and firstResult;
                                               
                        let secondResult = assertAllEqualWithDescription(
                            [
                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 0; length = 100 })).transactions, 
                                ?(0,100), "0-100"),  

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 225; length = 100 })).transactions, 
                                ?(225,325), "225-325"),

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 225; length = 1200 })).transactions, 
                                ?(225,1425), "225-1425"),

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 980; length = 100 })).transactions, 
                                ?(980,1080), "980-1080"),

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 3251; length = 2000 })).transactions, 
                                ?(3251,4999), "3251-4999"),

                                // GetAssertParamForTransactionCheck(await archive.get_transaction(1234), ?1234, "1234"),
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(2829), ?2829, "2829"),
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(3554), ?3554, "3554"),
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(3555), ?3555, "3555"),
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(9000), ?9000, "9000"),
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(15000), ?15000, "15000"),
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(25000), ?25000, "25000"),
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(54000), ?54000, "54000"),
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(54999), ?54999, "54999"),
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(55000), null, "55000"),
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(55001), null, "55001"),                                
                                // GetAssertParamForTransactionCheck(await archive.get_transaction(999999), null, "999999")                                
                            ]
                        );
                        
                        returnResult := returnResult and secondResult;
                        returnResult;  
                    },
                ),
            ],
        );
    };
};
