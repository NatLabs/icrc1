.PHONY: test docs actor-test

test:
	$(shell vessel bin)/moc -r $(shell vessel sources) -wasi-system-api ./tests/**/**.Test.mo

docs:
	$(shell vessel bin)/mo-doc
	$(shell vessel bin)/mo-doc --format plain

actor-test:
	-dfx start --background
	dfx deploy test
	dfx ledger fabricate-cycles --canister test
	dfx canister call test run_tests

ref-test:
	cd Dfnity-ICRC1-Reference && cargo run --bin runner -- -u http://127.0.0.1:8000 -c $(ID) -s ~/.config/dfx/identity/$(shell dfx identity whoami)/identity.pem

no-warn:
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell vessel bin)/moc -r $(shell vessel sources) -Werror -wasi-system-api