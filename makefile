TOKENINITFORTEST='( opt record { \
	name = "Test Token 587"; \
	symbol = "Test587"; \
	decimals = 6; \
	fee = 5_000; \
	max_supply = 1_000_000_000_000; \
	logo = ""; \
	initial_balances = vec { \
		record { \
			record { \
				owner = principal "$(TESTPRINCIPAL)"; \
				subaccount = null; \
			}; \
			300_000_000_000 \
		} \
	}; \
	min_burn_amount = 10_000; \
	minting_account = null; \
	advanced_settings = null; \
	minting_allowed=false; \
})' \

TESTIDENTITY=IdentityForTests
TESTIDENTITYMINTINGOWNER=IdentityForTestsMintingOwner
TESTPRINCIPAL=empty
TESTPRINCIPALMINTINGOWNER=empty
CANISTERID=empty

.PHONY: test docs actor-test

AddIdentities:
ifeq (,$(wildcard ~/.config/dfx/identity/$(TESTIDENTITY)/identity.pem))    
	@dfx identity new $(TESTIDENTITY)	
	@sleep 1	
	@dfx identity export $(TESTIDENTITY) > ~/.config/dfx/identity/$(TESTIDENTITY)/identity.pem
endif

ifeq (,$(wildcard ~/.config/dfx/identity/$(TESTIDENTITYMINTINGOWNER)/identity.pem))    
	@dfx identity new $(TESTIDENTITYMINTINGOWNER)	
	@sleep 1	
	@dfx identity export $(TESTIDENTITYMINTINGOWNER) > ~/.config/dfx/identity/$(TESTIDENTITYMINTINGOWNER)/identity.pem
endif

dfx-cache-install: 
	dfx cache install

test: dfx-cache-install
	$(shell mocv bin current)/moc -r $(shell mops sources) -wasi-system-api ./tests/**/**.Test.mo

no-warn: dfx-cache-install
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell mocv bin current)/moc -r $(shell mops sources) -Werror -wasi-system-api

docs:
	$(shell mocv bin current)/mo-doc
	$(shell mocv bin current)/mo-doc --format plain

internal-tests: dfx-cache-install
	-dfx start --background
	dfx deploy test
	dfx ledger fabricate-cycles --canister test
	dfx canister call test run_tests

ref-test: AddIdentities ref-test-before ref-test-execution ref-test-after
	
ref-test-before:
	@$(eval TESTPRINCIPAL=$(shell dfx identity get-principal --identity $(TESTIDENTITY)))
	@$(eval TESTPRINCIPALMINTINGOWNER=$(shell dfx identity get-principal --identity $(TESTIDENTITYMINTINGOWNER)))
	dfx stop
	dfx start --background --clean
	@echo identity for testing $(TESTIDENTITY)
	@echo identity as token owner $(TESTIDENTITYMINTINGOWNER)
	dfx deploy icrc1 --identity $(TESTIDENTITYMINTINGOWNER) --no-wallet --argument $(TOKENINITFORTEST)


ref-test-execution:
	@$(eval CANISTERID=$(shell dfx canister id icrc1))
	@echo CanisterId set to: $(CANISTERID)
	cd tests/Dfnity-ICRC1-Reference && cargo run --bin runner -- -u http://127.0.0.1:4943 -c $(CANISTERID) -s ~/.config/dfx/identity/$(TESTIDENTITY)/identity.pem

ref-test-after:
	dfx stop >NUL
	dfx start --background --clean >NUL


