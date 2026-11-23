.PHONY: project build run dmg clean

XCODEBUILD = xcodebuild -project Kumo.xcodeproj -scheme Kumo -destination 'platform=macOS,arch=arm64' -skipMacroValidation -skipPackagePluginValidation -quiet
LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
PRODUCTS = $$(xcodebuild -project Kumo.xcodeproj -scheme Kumo -configuration $(1) -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $$2}')/Kumo.app

project:
	xcodegen generate --quiet

build: project
	$(XCODEBUILD) -configuration Release build
	$(LSREGISTER) -u "$(call PRODUCTS,Release)" || true

run: project
	$(XCODEBUILD) -configuration Debug build
	@if [ -f signing/build.keychain-db ] && [ -f signing/p12-password.txt ]; then \
		security unlock-keychain -p "$$(cat signing/p12-password.txt)" "$(CURDIR)/signing/build.keychain-db" && \
		codesign --force --deep --keychain "$(CURDIR)/signing/build.keychain-db" --sign 71D358801440B0BE64781642ABAAECCD2B23048E \
			--entitlements Kumo/Resources/Kumo.entitlements "$(call PRODUCTS,Debug)"; \
	fi
	pkill -x Kumo || true
	rm -rf build/Kumo.app
	mkdir -p build
	ditto "$(call PRODUCTS,Debug)" build/Kumo.app
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$(CURDIR)/build/Kumo.app"
	open build/Kumo.app

dmg:
	./Scripts/package.sh

clean:
	rm -rf Kumo.xcodeproj build dist
