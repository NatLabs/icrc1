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
TESTPRINCIPAL=empty

TESTIDENTITYMINTINGOWNER=empty
TESTPRINCIPALMINTINGOWNER=empty

CANISTERID=empty
PEMDIR=~/.config/dfx/identity/$(TESTIDENTITY)

.PHONY: test docs actor-test

AddIdentities:
ifeq (,$(wildcard ./identityfortests.pem))    
	@dfx identity new $(TESTIDENTITY) --force --storage-mode plaintext	
	@sleep 1	
	@dfx identity export $(TESTIDENTITY) > $(PEMDIR)/identityfortests.pem
	
#	@dfx identity export $(TESTIDENTITY) > ~/.config/dfx/identity/$(TESTIDENTITY)/identity.pem
endif

dfx-cache-install: 
	dfx cache install -q

#test: dfx-cache-install
#	$(shell mocv bin current)/moc -r $(shell mops sources) -wasi-system-api ./tests/**/**.Test.mo

#no-warn: dfx-cache-install
#	find src -type f -name '*.mo' -print0 | xargs -0 $(shell mocv bin current)/moc -r $(shell mops sources) -Werror -wasi-system-api
#	find src -type f -name '*.mo' -print0 | xargs -0 $(shell mocv bin current)/moc -r $(shell mops sources) -Werror -wasi-system-api

docs:
	$(shell mocv bin current)/mo-doc
	$(shell mocv bin current)/mo-doc --format plain

internal-tests: dfx-cache-install
	@dfx stop
	@dfx start --background
	@sleep 5
	@dfx deploy test
	@dfx ledger fabricate-cycles --canister test --cycles 100000000000000
	@dfx canister call test run_tests

ref-test: update-pemdir AddIdentities ref-test-before ref-test-execution ref-test-after
	
ref-test-before:    
	@$(eval TESTIDENTITYMINTINGOWNER=$(shell dfx identity whoami))
	@$(eval TESTPRINCIPALMINTINGOWNER=$(shell dfx identity get-principal --identity $(TESTIDENTITYMINTINGOWNER)))	
	@$(eval TESTPRINCIPAL=$(shell dfx identity get-principal --identity $(TESTIDENTITY)))	
	dfx stop
	dfx start --background --clean
	@sleep 5
	@echo identity for testing $(TESTIDENTITY)
	@echo identity as token owner $(TESTIDENTITYMINTINGOWNER)	
	@dfx deploy icrc1 --identity $(TESTIDENTITYMINTINGOWNER) --no-wallet --argument $(TOKENINITFORTEST)
	@dfx ledger fabricate-cycles --canister icrc1 --cycles 10000000


ref-test-execution:
	@$(eval CANISTERID=$(shell dfx canister id icrc1))
	@echo CanisterId set to: $(CANISTERID)
	cd tests/Dfnity-ICRC1-Reference && cargo run --bin runner -- -u http://127.0.0.1:4943 -c $(CANISTERID) -s $(PEMDIR)/identityfortests.pem

ref-test-after:
	dfx stop >NUL
	dfx start --background --clean >NUL


update-pemdir:
ifeq ($(origin GITHUB_WORKSPACE),undefined)	
	@echo using PEM-file-directory: $(PEMDIR)
else
	@$(eval PEMDIR=$(GITHUB_WORKSPACE))
	@echo using PEM-file-directory: $(PEMDIR)	
endif 

 


