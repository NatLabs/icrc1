import Debug "mo:base/Debug";

import Archive "ICRC1/Archive.ActorTest";
import ICRC1 "ICRC1/ICRC1.ActorTest";
import AccountTest "ICRC1/Account.Test";
import Text "mo:base/Text";
import ActorSpec "./utils/ActorSpec";

actor {
    let { run } = ActorSpec;

    let test_modules = [

        //TODO: enable this test and make it succeed
        //{function = ICRC1.test; description="ICRC1.test":Text}

        {function = Archive.test; description="Archive.test":Text},      
        {function = AccountTest.test; description="Account.test":Text}
        
    ];

    public func run_tests() : async () {

        var someTestsFailed = false;
        for (test in test_modules.vals()) {

            Debug.print("Running: " # test.description);                        
            let success = ActorSpec.run([await test.function()]);

            if (success == false) {
                //Debug.trap("\1b[46;41mTests failed\1b[0m");
                Debug.print("\1b[46;41mTests failed\1b[0m");
                someTestsFailed:=true;
            } else {
                Debug.print("\1b[23;42;3m Success!\1b[0m");
            };
        };

        if (someTestsFailed){
            Debug.trap("\1b[46;41mThere are failed tests\1b[0m");
        }
        else{
            Debug.print("\1b[23;42;3m Gratulation! All tests succeeded!\1b[0m");
        }
    };
};
