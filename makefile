.PHONY: test docs actor-test

install-dfx-cache: 
	dfx cache install

test: install-dfx-cache
	$(shell dfx cache show)/moc -r $(shell mops sources) -wasi-system-api ./tests/**/**.Test.mo

no-warn: install-dfx-cache
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell dfx cache show)/moc -r $(shell mops sources) -Werror -wasi-system-api

docs:
	$(shell dfx cache show)/mo-doc
	$(shell dfx cache show)/mo-doc --format plain

actor-test: install-dfx-cache
	-dfx start --background
	dfx deploy test
	dfx ledger fabricate-cycles --canister test
	dfx canister call test run_tests

canister_id=$(shell dfx canister id icrc1)
user_id=$(shell dfx identity whoami)
ref-test: 
	-dfx start --background
	cat icrc1-default-args.txt | xargs -0 dfx deploy icrc1 --argument
	cd Dfnity-ICRC1-Reference && cargo run --bin runner -- -u http://127.0.0.1:8000 -c $(canister_id) -s ~/.config/dfx/identity/$(user_id)/identity.pem

