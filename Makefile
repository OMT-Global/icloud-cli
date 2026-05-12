SHELL := /bin/bash

.PHONY: help build test run clean

help:
	@printf "%s\n" \
		"make build        - build the Swift package" \
		"make test         - run Swift tests" \
		"make run ARGS=... - run the debug CLI" \
		"make clean        - remove SwiftPM build outputs"

build:
	swift build

test:
	swift test

run:
	swift run icloud-cli $(ARGS)

clean:
	swift package clean
