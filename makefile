.PHONY: test docs test_actor

test:
	$(shell vessel bin)/moc -r $(shell vessel sources) -wasi-system-api ./tests/**/**.Test.mo

docs:
	$(shell vessel bin)/mo-doc
	$(shell vessel bin)/mo-doc --format plain

actor_test:
	-dfx start --background
	-dfx deploy test
	-dfx canister call test run_tests
	dfx stop

no-warn:
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell vessel bin)/moc -r $(shell mops sources) -Werror -wasi-system-api