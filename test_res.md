 Finished dev [unoptimized + debuginfo] target(s) in 0.39s
     Running `target/debug/runner -u 'http://127.0.0.1:8000' -c rrkah-fqaaa-aaaaa-aaaaq-cai -s /Users/dire.sol/.config/dfx/identity/ic_admin/identity.pem`
TAP version 14
1..4
# failed to transfer 10000 tokens to gs7mh-qbkp7-jfg33-ywptc-ehdrh-fwqkx-7oz6p-p2m4v-oamim-bzjbo-vae
# 
# Caused by:
#     0: Failed to decode icrc1_transfer response as a Result<Nat, TransferError>
#     1: Fail to decode argument 0 from table0 to variant {
#          Ok : nat;
#          Err : variant {
#            GenericError : record { message : text; error_code : nat };
#            TemporarilyUnavailable;
#            BadBurn : record { min_burn_amount : nat };
#            Duplicate : record { duplicate_of : nat };
#            BadFee : record { expected_fee : nat };
#            CreatedInFuture : record { ledger_time : nat64 };
#            TooOld;
#            InsufficientFunds : record { balance : nat };
#          };
#        }
#     2: input: 4449444c086b029cc2017de58eb402016b08d1c4987c06c291ecb9027f94c1c7890402eb82a8970405a1c3ebfd0703f087e6db090493e5bec80c7feb9cdbd50f076c019bb3bea60a7d6c01bf9bb7f00d7d6c01a3bb918c0a786c018bbdf29b017d6c02c7ebc4d00971c498b1b50d7d6c019cbab69c027d0100_0000
#        table: type table0 = variant { 24_860 : nat; 5_048_165 : table1 }
#        type table1 = variant {
#          260_448_849 : table6;
#          658_180_290;
#          1_093_787_796 : table2;
#          1_122_632_043 : table5;
#          2_142_953_889 : table3;
#          2_608_432_112 : table4;
#          3_373_249_171;
#          4_206_284_395 : table7;
#        }
#        type table2 = record { 2_765_068_699 : nat }
#        type table3 = record { 3_725_446_591 : nat }
#        type table4 = record { 2_709_806_499 : nat64 }
#        type table5 = record { 326_934_155 : nat }
#        type table6 = record { 2_584_819_143 : text; 3_601_615_940 : nat }
#        type table7 = record { 596_483_356 : nat }
#        wire_type: table0, expect_type: variant {
#          Ok : nat;
#          Err : variant {
#            GenericError : record { message : text; error_code : nat };
#            TemporarilyUnavailable;
#            BadBurn : record { min_burn_amount : nat };
#            Duplicate : record { duplicate_of : nat };
#            BadFee : record { expected_fee : nat };
#            CreatedInFuture : record { ledger_time : nat64 };
#            TooOld;
#            InsufficientFunds : record { balance : nat };
#          };
#        }
#     3: table0 is not a subtype of variant {
#          Ok : nat;
#          Err : variant {
#            GenericError : record { message : text; error_code : nat };
#            TemporarilyUnavailable;
#            BadBurn : record { min_burn_amount : nat };
#            Duplicate : record { duplicate_of : nat };
#            BadFee : record { expected_fee : nat };
#            CreatedInFuture : record { ledger_time : nat64 };
#            TooOld;
#            InsufficientFunds : record { balance : nat };
#          };
#        }
#     4: Variant field 24_860 not found in the expected type
not ok 1 - basic:transfer
# minting account cannot hold any funds
# 
# Caused by:
#     Expected the balance of account Account { owner: Principal { len: 29, bytes: [178, 125, 97, 49, 203, 4, 143, 152, 7, 213, 28, 19, 163, 157, 209, 45, 215, 42, 146, 255, 207, 201, 150, 217, 208, 205, 26, 208, 2] }, subaccount: None } to be 0, got 1_000_000_000_000
not ok 2 - basic:burn
ok 3 - basic:metadata
ok 4 - basic:supported_standards