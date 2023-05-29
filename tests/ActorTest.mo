import Debug "mo:base/Debug";

import Archive1 "ICRC1/Archive.ActorTest";
import ICRC1 "ICRC1/ICRC1.ActorTest";
import Archive2 "ICRC2/Archive.ActorTest";
import ICRC2 "ICRC2/ICRC2.ActorTest";
import Archive3 "ICRC3/Archive.ActorTest";
import ICRC3 "ICRC3/ICRC3.ActorTest";

import ActorSpec "./utils/ActorSpec";

actor {
    let { run } = ActorSpec;

    let test_modules = [
        Archive1.test,
        ICRC1.test,
        Archive2.test,
        ICRC2.test,
        Archive3.test,
        ICRC3.test,
    ];

    public func run_tests() : async () {
        for (test in test_modules.vals()) {
            let success = ActorSpec.run([await test()]);

            if (success == false) {
                Debug.trap("\1b[46;41mTests failed\1b[0m");
            } else {
                Debug.print("\1b[23;42;3m Success!\1b[0m");
            };
        };
    };
};
