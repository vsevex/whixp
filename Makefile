# Whixp native transport: build Rust crate and copy libs to platform folders.
# Usage:
#   make          or  make release   - build for current host and copy
#   make macos    - build for macOS and copy to macos/
#   make linux    - build for Linux and copy to linux/
#   make windows  - build for Windows and copy to windows/
#   make android  - build for Android ABIs and copy to android/src/main/jniLibs/
#   make ios      - build for iOS (device + sim) and copy to ios/
#   make all      - build host platform only (same as make release)

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
NATIVE    := $(REPO_ROOT)/native/whixp_transport
TARGET    := $(NATIVE)/target

# Detect host for default build
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

.PHONY: release all macos linux linux-cross linux-cross-docker windows android ios test clean help copy-macos copy-linux copy-windows

help:
	@echo "Targets: release (default), macos, linux, windows, android, ios, all, clean, help"
	@echo "  make release  - build for current host and copy lib to platform folder"
	@echo "  make all      - same as release"
	@echo "  make macos    - build for macOS (dylib -> macos/)"
	@echo "  make linux    - build for Linux on Linux host (so -> linux/)"
	@echo "  make linux-cross - cross to Linux from Mac with Zig (brew install zig)"
	@echo "  make linux-cross-docker - cross to Linux with Docker (cargo install cross)"
	@echo "  make windows  - build for Windows (dll -> windows/)"
	@echo "  make android  - build for Android ABIs (so -> android/.../jniLibs/)"
	@echo "  make ios      - build for iOS (static lib -> ios/)"

release: host-build host-copy
all: release

# --- Host build + copy (one command for current platform) ---
host-build:
	cd $(NATIVE) && cargo build --release

host-copy: host-build
	@case "$(UNAME_S)" in \
		Darwin)  cp $(TARGET)/release/libwhixp_transport.dylib $(REPO_ROOT)/macos/ && echo "Copied -> macos/" ;; \
		Linux)   cp $(TARGET)/release/libwhixp_transport.so $(REPO_ROOT)/linux/ && echo "Copied -> linux/" ;; \
		MINGW*|MSYS*|CYGWIN*) cp $(TARGET)/release/whixp_transport.dll $(REPO_ROOT)/windows/ && echo "Copied -> windows/" ;; \
		*) echo "Unknown host $(UNAME_S), run make macos|linux|windows explicitly" ;; \
	esac

# --- macOS ---
macos:
	cd $(NATIVE) && cargo build --release
	@mkdir -p $(REPO_ROOT)/macos
	cp $(TARGET)/release/libwhixp_transport.dylib $(REPO_ROOT)/macos/
	@echo "Copied libwhixp_transport.dylib -> macos/"

copy-macos: host-build
	cp $(TARGET)/release/libwhixp_transport.dylib $(REPO_ROOT)/macos/
	@echo "Copied libwhixp_transport.dylib -> macos/"

# --- Linux ---
# On Linux host: make linux. On Mac: use make linux-cross (Zig) or make linux-cross-docker (Docker).
LINUX_GNU_TARGET := x86_64-unknown-linux-gnu

linux:
	@if [ "$(UNAME_S)" != "Linux" ]; then \
		echo "Error: make linux builds for current host. You are on $(UNAME_S)."; \
		echo "  Use: make linux-cross      (needs: brew install zig, rustup target add $(LINUX_GNU_TARGET))"; \
		echo "  Or:  make linux-cross-docker  (needs: cargo install cross)"; \
		exit 1; \
	fi
	cd $(NATIVE) && cargo build --release
	@mkdir -p $(REPO_ROOT)/linux
	cp $(TARGET)/release/libwhixp_transport.so $(REPO_ROOT)/linux/
	@echo "Copied libwhixp_transport.so -> linux/"

# Cross-compile to Linux from Mac using Zig as linker/CC (brew install zig).
linux-cross:
	@command -v zig >/dev/null 2>&1 || { echo "Error: zig not found. Install: brew install zig"; exit 1; }
	cd $(NATIVE) && rustup target add $(LINUX_GNU_TARGET) 2>/dev/null || true
	cd $(NATIVE) && \
		export CC_x86_64_unknown_linux_gnu="zig cc" && \
		export AR_x86_64_unknown_linux_gnu="zig ar" && \
		export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="zig cc" && \
		cargo build --release --target $(LINUX_GNU_TARGET)
	mkdir -p $(REPO_ROOT)/linux
	cp $(TARGET)/$(LINUX_GNU_TARGET)/release/libwhixp_transport.so $(REPO_ROOT)/linux/
	@echo "Copied libwhixp_transport.so -> linux/ (cross with zig)"

# Cross-compile to Linux using Docker (cargo install cross). No local linker needed.
linux-cross-docker:
	@command -v cross >/dev/null 2>&1 || { echo "Error: cross not found. Install: cargo install cross"; exit 1; }
	cd $(NATIVE) && rustup target add $(LINUX_GNU_TARGET) 2>/dev/null || true
	cd $(NATIVE) && cross build --release --target $(LINUX_GNU_TARGET)
	mkdir -p $(REPO_ROOT)/linux
	cp $(TARGET)/$(LINUX_GNU_TARGET)/release/libwhixp_transport.so $(REPO_ROOT)/linux/
	@echo "Copied libwhixp_transport.so -> linux/ (cross with docker)"

copy-linux: host-build
	@if [ "$(UNAME_S)" != "Linux" ]; then \
		echo "No libwhixp_transport.so (host is $(UNAME_S)). Run make linux on Linux."; exit 1; \
	fi
	cp $(TARGET)/release/libwhixp_transport.so $(REPO_ROOT)/linux/
	@echo "Copied libwhixp_transport.so -> linux/"

# --- Windows: on Windows build natively; on Mac/Linux cross-compile.
# Cross-build from Mac needs: rustup target add x86_64-pc-windows-gnu
# and MinGW toolchain (e.g. on macOS: brew install mingw-w64).
# TLS uses rustls (no OpenSSL), but ring/windows-sys still need the GNU toolchain.
WIN_TARGET := x86_64-pc-windows-gnu
windows:
	@case "$(UNAME_S)" in \
		MINGW*|MSYS*|CYGWIN*) \
			cd $(NATIVE) && cargo build --release && \
			cp $(TARGET)/release/whixp_transport.dll $(REPO_ROOT)/windows/ && \
			echo "Copied whixp_transport.dll -> windows/" ;; \
		*) \
			cd $(NATIVE) && cargo build --release --target $(WIN_TARGET) && \
			cp $(TARGET)/$(WIN_TARGET)/release/whixp_transport.dll $(REPO_ROOT)/windows/ && \
			echo "Copied whixp_transport.dll -> windows/ (cross-built)" ;; \
	esac

copy-windows: host-build
	@if [ -f $(TARGET)/release/whixp_transport.dll ]; then \
		cp $(TARGET)/release/whixp_transport.dll $(REPO_ROOT)/windows/ && echo "Copied -> windows/"; \
	else \
		echo "No whixp_transport.dll (not on Windows). Run: make windows"; \
	fi

# --- Android (requires rustup targets + Android NDK) ---
# ring/aws-lc-sys need a C compiler for the target. Set ANDROID_NDK_HOME to your NDK root
# (e.g. $HOME/Library/Android/sdk/ndk/27.1.12297018 or from Android Studio).
ANDROID_TARGETS := aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
ANDROID_API ?= 21
# NDK host tag: darwin-aarch64 (M1/M2) or darwin-x86_64
NDK_HOST := darwin-$(UNAME_M)

android-check-ndk:
	@if [ -z "$$ANDROID_NDK_HOME" ]; then \
		echo "Error: ANDROID_NDK_HOME not set. Install Android NDK and run:"; \
		echo "  export ANDROID_NDK_HOME=\$$HOME/Library/Android/sdk/ndk/<version>"; \
		echo "  make android"; \
		exit 1; \
	fi
	@if [ ! -d "$$ANDROID_NDK_HOME" ]; then \
		echo "Error: ANDROID_NDK_HOME=$$ANDROID_NDK_HOME not found."; \
		exit 1; \
	fi

ANDROID_CC_aarch64  := aarch64-linux-android$(ANDROID_API)-clang
ANDROID_CC_armv7    := armv7a-linux-androideabi$(ANDROID_API)-clang
ANDROID_CC_x86_64   := x86_64-linux-android$(ANDROID_API)-clang

android: android-check-ndk android-arm64-v8a android-armeabi-v7a android-x86_64
	@echo "Android builds done -> android/src/main/jniLibs/"

android-arm64-v8a: android-check-ndk
	@NDK=$$ANDROID_NDK_HOME; \
	if [ -d "$$NDK/toolchains/llvm/prebuilt/$(NDK_HOST)/bin" ]; then \
	  BIN="$$NDK/toolchains/llvm/prebuilt/$(NDK_HOST)/bin"; \
	else \
	  BIN="$$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin"; \
	fi; \
	export CC_aarch64_linux_android="$$BIN/$(ANDROID_CC_aarch64)" CXX_aarch64_linux_android="$$BIN/$(ANDROID_CC_aarch64)" AR_aarch64_linux_android="$$BIN/llvm-ar" CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$$BIN/$(ANDROID_CC_aarch64)"; \
	cd $(NATIVE) && cargo build --release --target aarch64-linux-android
	mkdir -p $(REPO_ROOT)/android/src/main/jniLibs/arm64-v8a
	cp $(TARGET)/aarch64-linux-android/release/libwhixp_transport.so $(REPO_ROOT)/android/src/main/jniLibs/arm64-v8a/

android-armeabi-v7a: android-check-ndk
	@NDK=$$ANDROID_NDK_HOME; \
	if [ -d "$$NDK/toolchains/llvm/prebuilt/$(NDK_HOST)/bin" ]; then \
	  BIN="$$NDK/toolchains/llvm/prebuilt/$(NDK_HOST)/bin"; \
	else \
	  BIN="$$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin"; \
	fi; \
	export CC_armv7_linux_androideabi="$$BIN/$(ANDROID_CC_armv7)" CXX_armv7_linux_androideabi="$$BIN/$(ANDROID_CC_armv7)" AR_armv7_linux_androideabi="$$BIN/llvm-ar" CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER="$$BIN/$(ANDROID_CC_armv7)"; \
	cd $(NATIVE) && cargo build --release --target armv7-linux-androideabi
	mkdir -p $(REPO_ROOT)/android/src/main/jniLibs/armeabi-v7a
	cp $(TARGET)/armv7-linux-androideabi/release/libwhixp_transport.so $(REPO_ROOT)/android/src/main/jniLibs/armeabi-v7a/

android-x86_64: android-check-ndk
	@NDK=$$ANDROID_NDK_HOME; \
	if [ -d "$$NDK/toolchains/llvm/prebuilt/$(NDK_HOST)/bin" ]; then \
	  BIN="$$NDK/toolchains/llvm/prebuilt/$(NDK_HOST)/bin"; \
	else \
	  BIN="$$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin"; \
	fi; \
	export CC_x86_64_linux_android="$$BIN/$(ANDROID_CC_x86_64)" CXX_x86_64_linux_android="$$BIN/$(ANDROID_CC_x86_64)" AR_x86_64_linux_android="$$BIN/llvm-ar" CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="$$BIN/$(ANDROID_CC_x86_64)"; \
	cd $(NATIVE) && cargo build --release --target x86_64-linux-android
	mkdir -p $(REPO_ROOT)/android/src/main/jniLibs/x86_64
	cp $(TARGET)/x86_64-linux-android/release/libwhixp_transport.so $(REPO_ROOT)/android/src/main/jniLibs/x86_64/

# --- iOS (macOS only; requires Xcode). Device and sim are both arm64 so we can't lipo them together. ---
# Output: libwhixp_transport.a = device (arm64), libwhixp_transport_sim.a = simulator (arm64 + x86_64).
# ios-xcframework also builds WhixpTransport.xcframework so CocoaPods links the right slice (fixes "symbol not found" on simulator).
IOS_DEVICE  := aarch64-apple-ios
IOS_SIM_ARM := aarch64-apple-ios-sim
IOS_SIM_X86 := x86_64-apple-ios
ios: ios-build ios-lipo
	@echo "iOS build done -> ios/libwhixp_transport.a (device), ios/libwhixp_transport_sim.a (simulator)"

ios-build:
	cd $(NATIVE) && cargo build --release --target $(IOS_DEVICE)
	cd $(NATIVE) && cargo build --release --target $(IOS_SIM_ARM)
	cd $(NATIVE) && cargo build --release --target $(IOS_SIM_X86)

ios-lipo: ios-build
	mkdir -p $(REPO_ROOT)/ios
	cp $(TARGET)/$(IOS_DEVICE)/release/libwhixp_transport.a $(REPO_ROOT)/ios/libwhixp_transport.a
	lipo -create \
		$(TARGET)/$(IOS_SIM_ARM)/release/libwhixp_transport.a \
		$(TARGET)/$(IOS_SIM_X86)/release/libwhixp_transport.a \
		-output $(REPO_ROOT)/ios/libwhixp_transport_sim.a
	@echo "Created ios/libwhixp_transport.a (device arm64), ios/libwhixp_transport_sim.a (simulator arm64+x86_64)"

# XCFramework only: build from target/ into a temp dir, output only WhixpTransport.xcframework to ios/ (no .a copies = smaller ios/).
ios-xcframework: ios-build
	@mkdir -p $(REPO_ROOT)/ios/Headers
	@mkdir -p $(REPO_ROOT)/ios/xcframework-build/ios-arm64 $(REPO_ROOT)/ios/xcframework-build/ios-arm64_x86_64-simulator
	@cp $(TARGET)/$(IOS_DEVICE)/release/libwhixp_transport.a $(REPO_ROOT)/ios/xcframework-build/ios-arm64/
	@lipo -create \
		$(TARGET)/$(IOS_SIM_ARM)/release/libwhixp_transport.a \
		$(TARGET)/$(IOS_SIM_X86)/release/libwhixp_transport.a \
		-output $(REPO_ROOT)/ios/xcframework-build/ios-arm64_x86_64-simulator/libwhixp_transport.a
	xcodebuild -create-xcframework \
		-library $(REPO_ROOT)/ios/xcframework-build/ios-arm64/libwhixp_transport.a -headers $(REPO_ROOT)/ios/Headers \
		-library $(REPO_ROOT)/ios/xcframework-build/ios-arm64_x86_64-simulator/libwhixp_transport.a -headers $(REPO_ROOT)/ios/Headers \
		-output $(REPO_ROOT)/ios/WhixpTransport.xcframework
	@rm -rf $(REPO_ROOT)/ios/xcframework-build
	@echo "Created ios/WhixpTransport.xcframework (device + simulator)"

# --- Tests ---
# Use flutter test so Flutter engine is available (path_provider etc.). dart_test.yaml sets concurrency: 1.
# If tests are still killed (SIGKILL), run with more heap:
#   DART_VM_OPTIONS="--old_gen_heap_size=2048" make test
test:
	flutter test

# --- Clean ---
clean:
	cd $(NATIVE) && cargo clean
	@echo "Cleaned $(TARGET)"
