.PHONY: test compile-tests docs no-warn

# runs all tests using the moc interpreter (not all features in motoko are supported)
test: 
	find tests -type f -name '*.Test.mo' -print0 | xargs -0 $(shell mocv bin current)/moc -r $(shell mops sources) -wasi-system-api

# treats warnings as errors and prints them to stdout
no-warn:
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell mocv bin current)/moc -r $(shell mops sources) -Werror -wasi-system-api

docs: 
	$(shell mocv bin current)/mo-doc
	$(shell mocv bin current)/mo-doc --format plain