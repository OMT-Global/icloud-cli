SHELL := /bin/bash
SWIFT_FLAGS ?=

.PHONY: help build test release run clean

help:
	@printf "%s\n" \
		"make build        - build the Swift package" \
		"make test         - run Swift tests" \
		"make release      - build dist/icloud-cli and checksum" \
		"make run ARGS=... - run the debug CLI" \
		"make clean        - remove SwiftPM build outputs"

build:
	swift build $(SWIFT_FLAGS)

test:
	swift test $(SWIFT_FLAGS)

release:
	swift build $(SWIFT_FLAGS) -c release
	mkdir -p dist
	cp .build/release/icloud-cli dist/icloud-cli
	shasum -a 256 dist/icloud-cli > dist/icloud-cli.sha256

run:
	swift run icloud-cli $(ARGS)

clean:
	swift package clean
