VERSION ?= 0.5
DIST_DIR ?= dist
LUA ?= lua
.PHONY: all build check-distributions ipa-altstore smoke-simulator test test-plugin koplugin clean

all: test test-plugin build koplugin

test:
	xcrun swift test --package-path Packages/RemoteCore

build:
	xcodebuild \
		-project KOReaderiOSRemote.xcodeproj \
		-scheme KORemoteFull \
		-destination 'generic/platform=iOS Simulator' \
		CODE_SIGNING_ALLOWED=NO build

check-distributions:
	./scripts/check-distributions.sh

ipa-altstore:
	./scripts/build-altstore-ipa.sh $(VERSION)

smoke-simulator:
	./scripts/smoke-simulator.sh

test-plugin:
	$(LUA) tests/httpserver_spec.lua
	$(LUA) tests/plugin_spec.lua
	python3 -m unittest discover -s tests

koplugin:
	python3 scripts/package-plugin.py "$(VERSION)" --output "$(DIST_DIR)"

clean:
	rm -rf $(DIST_DIR) Packages/RemoteCore/.build
