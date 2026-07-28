SHELL := /bin/bash
SWIFT_FLAGS ?=

.PHONY: help build test coverage mutation-test release run clean

help:
	@printf "%s\n" \
		"make build        - build the Swift package" \
		"make test         - run Swift tests" \
		"make coverage     - run source coverage gate" \
		"make mutation-test - run mutation smoke checks" \
		"make release VERSION=x.y.z - build a signed universal macOS DMG" \
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
	bash scripts/release/build-macos-artifact.sh "$(VERSION)"

run:
	swift run icloud-cli $(ARGS)

clean:
	swift package clean
