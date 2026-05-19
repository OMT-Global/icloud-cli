SHELL := /bin/bash
SWIFT_FLAGS ?=

.PHONY: help build test coverage mutation-test release run clean

help:
	@printf "%s\n" \
		"make build        - build the Swift package" \
		"make test         - run Swift tests" \
		"make coverage     - run source coverage gate" \
		"make mutation-test - run mutation smoke checks" \
		"make release      - build dist/icloud-cli and checksum" \
		"make run ARGS=... - run the debug CLI" \
		"make clean        - remove SwiftPM build outputs"

build:
	swift build $(SWIFT_FLAGS)

test:
	swift test $(SWIFT_FLAGS)

coverage:
	bash scripts/ci/check-coverage.sh

mutation-test:
	bash scripts/ci/run-mutation-smoke.sh

release:
	swift build $(SWIFT_FLAGS) -c release
	mkdir -p dist
	cp "$$(swift build $(SWIFT_FLAGS) -c release --show-bin-path)/icloud-cli" dist/icloud-cli
	shasum -a 256 dist/icloud-cli > dist/icloud-cli.sha256

run:
	swift run icloud-cli $(ARGS)

clean:
	swift package clean
