VERSION ?= 2.0.0
DIST_DIR ?= dist
PLUGIN_DIR ?= remote_turner.koplugin
.PHONY: all build test koplugin clean

all: test build koplugin

test:
	xcrun swift test --package-path Packages/RemoteCore

build:
	xcodebuild \
		-project KOReaderiOSRemote.xcodeproj \
		-scheme KORemote \
		-destination 'generic/platform=iOS Simulator' \
		CODE_SIGNING_ALLOWED=NO build

koplugin:
	mkdir -p $(DIST_DIR)
	zip -r $(DIST_DIR)/remote_turner-$(VERSION).koplugin.zip $(PLUGIN_DIR)

clean:
	rm -rf $(DIST_DIR) Packages/RemoteCore/.build
