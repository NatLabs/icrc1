test:
	$(shell vessel bin)/moc -r $(shell vessel sources) -wasi-system-api ./tests/**/**.Test.mo

doc:
	$(shell vessel bin)/mo-doc
	$(shell vessel bin)/mo-doc --format plain

test_actor:
	dfx deploy test
	dfx canister call test run_tests