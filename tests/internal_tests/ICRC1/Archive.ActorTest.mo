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

import Archive "../../../src/ICRC1/Canisters/Archive";
import T "../../../src/ICRC1/Types/Types.All";

import ActorSpec "../utils/ActorSpec";

module {

    private type Transaction = T.TransactionTypes.Transaction;

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

    func new_tx(i : Nat) : Transaction {
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
    func txs_range(start : Nat, end : Nat) : [Transaction] {
        Array.tabulate(
            (end - start) : Nat,
            func(i : Nat) : Transaction {
                new_tx(start + i);
            },
        );
    };

    func new_txs(length : Nat) : [Transaction] {
        txs_range(0, length);
    };

    func new_txs_range(from:Nat, length : Nat) : [Transaction] {
        txs_range(from, length);
    };

    let TC = 1_000_000_000_000;
    let CREATE_CANISTER = 100_000_000_000;

    func create_canister_and_add_cycles(n : Float) {
        EC.add(
            CREATE_CANISTER + Int.abs(Float.toInt(n * 1_000_000_000_000)),
        );
    };
 

    func GetAssertParamForTransactionCheck(actualTransaction:?Transaction, index:?Nat, description:Text)
    : ActorSpec.AssertParam<Transaction,Transaction>{ 

        let returnValue :ActorSpec.AssertParam<Transaction,Transaction> =                 
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

        func GetAssertParamForTransactionsCheck(actualTransactions:[Transaction], fromTo:?(fromIndex:Nat, toIndex:Nat), description:Text)
    : ActorSpec.AssertParam<[Transaction],[Transaction]>{ 

        let returnValue :ActorSpec.AssertParam<[Transaction],[Transaction]> =                 
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

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 10; length = 15 })).transactions, 
                                ?(10,25), "10-25"),  

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 225; length = 100 })).transactions, 
                                ?(225,325), "225-325"),

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 225; length = 1200 })).transactions, 
                                ?(225,1425), "225-1425"),

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 225; length = 3000 })).transactions, 
                                ?(225,3225), "225-3225"),

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 980; length = 100 })).transactions, 
                                ?(980,1080), "980-1080"),

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 3251; length = 2000 })).transactions, 
                                ?(3251,5251), "3251-5251"),

                                GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 451; length = 3200 })).transactions, 
                                ?(451,3651), "451-3651"),     

                                 GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 6800; length = 3000 })).transactions, 
                                ?(6800,9000), "6800-9800"),  

                                 GetAssertParamForTransactionsCheck( (await archive.get_transactions({ start = 8300; length = 3000 })).transactions, 
                                ?(8300,9000), "8300-11300"),                                                         
                            
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
