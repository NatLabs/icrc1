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
	minting_allowed=true; \
})' \

TESTIDENTITY=IdentityForTests
TESTPRINCIPAL=empty

TESTIDENTITYMINTINGOWNER=empty
TESTPRINCIPALMINTINGOWNER=empty

CANISTERID=empty
PEMDIR=~/.config/dfx/identity/$(TESTIDENTITY)

.PHONY: test docs actor-test

AddIdentities:
ifeq (,$(wildcard $(PEMDIR)/identityfortests.pem))   
	@dfx identity new $(TESTIDENTITY) --force --storage-mode plaintext	
	@sleep 1	
	@dfx identity export $(TESTIDENTITY) > $(PEMDIR)/identityfortests.pem	
endif

dfx-cache-install: 
	dfx cache install -q

test: dfx-cache-install
	$(shell mocv bin current)/moc -r $(shell mops sources) -wasi-system-api ./tests/**/**.Test.mo

no-warn: dfx-cache-install
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell mocv bin current)/moc -r $(shell mops sources) -Werror -wasi-system-api

docs:
	$(shell mocv bin current)/mo-doc
	$(shell mocv bin current)/mo-doc --format plain

internal-tests: install-check dfx-cache-install
	@dfx stop
	@dfx start --background --clean
	@sleep 5
	@dfx deploy test
	@dfx ledger fabricate-cycles --canister test --cycles 100000000000000
	@dfx canister call test run_tests

ref-test: install-check update-variables AddIdentities ref-test-before ref-test-execution ref-test-after
	
ref-test-before:    
	@$(eval TESTIDENTITYMINTINGOWNER=$(shell dfx identity whoami))
	@$(eval TESTPRINCIPALMINTINGOWNER=$(shell dfx identity get-principal --identity $(TESTIDENTITYMINTINGOWNER)))	
	@$(eval TESTPRINCIPAL=$(shell dfx identity get-principal --identity $(TESTIDENTITY)))	
	dfx stop
	dfx start --background --clean
	@sleep 5
	@echo identity for testing $(TESTIDENTITY)
	@echo identity as token owner $(TESTIDENTITYMINTINGOWNER)	
	@echo dfx deploy icrc1 --identity $(TESTIDENTITYMINTINGOWNER) --no-wallet --argument $(TOKENINITFORTEST)
	@dfx deploy icrc1 --identity $(TESTIDENTITYMINTINGOWNER) --no-wallet --argument $(TOKENINITFORTEST)
	@dfx ledger fabricate-cycles --canister icrc1 --cycles 10000000


ref-test-execution:
	@$(eval CANISTERID=$(shell dfx canister id icrc1))
	@echo CanisterId set to: $(CANISTERID)
	cd tests/Dfnity-ICRC1-Reference && cargo run --bin runner -- -u http://127.0.0.1:4943 -c $(CANISTERID) -s $(PEMDIR)/identityfortests.pem

ref-test-after:
	dfx stop >NUL
	dfx start --background --clean >NUL

update-variables:
ifeq ($(origin GITHUB_WORKSPACE),undefined)	
#on local computer	
	@echo using PEM-file-directory: $(PEMDIR)
else
#inside build execution on server		
	@$(eval PEMDIR=$(GITHUB_WORKSPACE))
	@echo using PEM-file-directory: $(PEMDIR)	
endif 


install-check:
ifeq (, $(shell which curl))
	@echo No curl is installed, curl will be installed now.... 
	@sudo apt-get install curl -y
endif

ifeq (,$(shell which $(HOME)/bin/dfx))	
	@echo No dfx is installed, dfx will be installed now....
	curl -fsSL https://internetcomputer.org/install.sh -o install_dfx.sh
	chmod +x install_dfx.sh
	./install_dfx.sh
	rm install_dfx.sh		
endif

ifeq (, $(shell which nodejs))
	sudo apt install nodejs -y
endif

ifeq (, $(shell which npm))
	sudo apt install npm -y
endif

ifeq (, $(shell which mops))
	sudo npm i -g ic-mops
endif

ifeq (, $(shell which $(HOME)/bin/vessel))	
	rm installvessel.sh -f
	echo '#install vessel'>installvessel.sh
	echo cd $(HOME)/bin>>installvessel.sh
	echo wget https://github.com/dfinity/vessel/releases/download/v0.7.0/vessel-linux64 >> installvessel.sh
	echo mv vessel-linux64 vessel >>installvessel.sh
	echo chmod +x vessel>>installvessel.sh
	chmod +x installvessel.sh
	./installvessel.sh
	rm installvessel.sh -f
endif	
	
ifeq (, $(shell which pkg-config))
	sudo apt install pkg-config -y
endif
	
ifeq (,$(wildcard $(HOME)/.rustup))  
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
endif	


