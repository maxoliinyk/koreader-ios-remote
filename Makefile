VERSION ?= 2.0.0
DIST_DIR ?= dist
PLUGIN_DIR ?= remote_turner.koplugin
.PHONY: all build check-distributions ipa-altstore smoke-simulator test koplugin clean

all: test build koplugin

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

koplugin:
	mkdir -p $(DIST_DIR)
	zip -r $(DIST_DIR)/remote_turner-$(VERSION).koplugin.zip $(PLUGIN_DIR)

clean:
	rm -rf $(DIST_DIR) Packages/RemoteCore/.build
