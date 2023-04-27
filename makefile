.PHONY: test docs actor-test

install-dfx-cache: 
	dfx cache install

test: install-dfx-cache
	$(shell dfx cache show)/moc -r $(shell mops sources) -wasi-system-api ./tests/**/**.Test.mo --package base ~/.cache/dfinity/versions/0.13.1/base

no-warn: install-dfx-cache
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell dfx cache show)/moc -r $(shell mops sources) -Werror -wasi-system-api

docs:
	$(shell dfx cache show)/mo-doc
	$(shell dfx cache show)/mo-doc --format plain

actor-test: install-dfx-cache
	-dfx start --background
	dfx deploy test --no-wallet --identity anonymous
	dfx ledger fabricate-cycles --canister test
	dfx canister call test run_tests

ref-test:
	-dfx start --background
	cat icrc1-default-args.txt | xargs -0 dfx deploy icrc1 --identity default --argument
	CANISTER=$$(dfx canister id icrc1); \
	USER=$$(dfx identity whoami); \
	cd Dfnity-ICRC1-Reference && cargo run --bin runner -- -u http://127.0.0.1:4943 -c $$CANISTER -s ~/.config/dfx/identity/$$USER/identity.pem