VERSION ?= 2.0.0
DIST_DIR ?= dist
PLUGIN_DIR ?= remote_turner.koplugin
DEVELOPER_DIR ?= /Applications/Xcode-27.0.0-beta.app/Contents/Developer

.PHONY: all build test koplugin clean

all: test build koplugin

test:
	DEVELOPER_DIR=$(DEVELOPER_DIR) xcrun swift test --package-path Packages/RemoteCore

build:
	DEVELOPER_DIR=$(DEVELOPER_DIR) xcodebuild \
		-project KOReaderRemote.xcodeproj \
		-scheme KOReaderRemote \
		-destination 'generic/platform=iOS Simulator' \
		CODE_SIGNING_ALLOWED=NO build

koplugin:
	mkdir -p $(DIST_DIR)
	cd $(PLUGIN_DIR) && zip -r ../$(DIST_DIR)/remote_turner-$(VERSION).koplugin.zip .

clean:
	rm -rf $(DIST_DIR) Packages/RemoteCore/.build
