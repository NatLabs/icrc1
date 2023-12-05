import Debug "mo:base/Debug";

import Archive "ICRC1/Archive.ActorTest";
import ICRC1 "ICRC1/ICRC1.ActorTest";
import Text "mo:base/Text";
import ActorSpec "./utils/ActorSpec";

actor {
    let { run } = ActorSpec;

    let test_modules = [
        {function = Archive.test; description="Archive.test":Text}
        //{function = ICRC1.test; description="ICRC1.test":Text}
        
    ];

    public func run_tests() : async () {
        for (test in test_modules.vals()) {

            Debug.print("Running: " # test.description);
            

            //Debug.print("Running Test: " # debug_show(test));
            let success = ActorSpec.run([await test.function()]);

            if (success == false) {
                Debug.trap("\1b[46;41mTests failed\1b[0m");
                //Debug.print("\1b[46;41mTests failed\1b[0m");
            } else {
                Debug.print("\1b[23;42;3m Success!\1b[0m");
            };
        };
    };
};
