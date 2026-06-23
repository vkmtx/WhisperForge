#!/bin/zsh

JUST_BUILD=false
if [[ "$1" == "build" ]]; then
    JUST_BUILD=true
fi

# Configure libwhisper
echo "Configuring libwhisper..."
cmake -G Xcode -B libwhisper/build -S libwhisper
if [[ $? -ne 0 ]]; then
    echo "CMake configuration failed!"
    exit 1
fi

echo "Building autocorrect-swift..."
mkdir -p build
cargo build -p autocorrect-swift --release --target aarch64-apple-darwin --manifest-path=asian-autocorrect/Cargo.toml
cp ./asian-autocorrect/target/aarch64-apple-darwin/release/libautocorrect_swift.dylib ./build/libautocorrect_swift.dylib
install_name_tool -id "@rpath/libautocorrect_swift.dylib" ./build/libautocorrect_swift.dylib
codesign --force --sign - ./build/libautocorrect_swift.dylib
if [[ $? -ne 0 ]]; then
    echo "Cargo build failed!"
    exit 1
fi

echo "Copying libomp.dylib..."
cp /opt/homebrew/opt/libomp/lib/libomp.dylib ./build/libomp.dylib
install_name_tool -id "@rpath/libomp.dylib" ./build/libomp.dylib
codesign --force --sign - ./build/libomp.dylib

# Resolve packages, then patch FluidAudio 0.11.0 to Swift 5 mode. Xcode 26 / Swift 6
# rejects pre-existing data races in FluidAudio's unused streaming code; this app only
# uses the batch API. Idempotent — see Scripts/patch_fluidaudio.py.
echo "Resolving Swift packages..."
xcodebuild -resolvePackageDependencies -scheme WhisperForge -clonedSourcePackagesDirPath SourcePackages -skipPackagePluginValidation > /dev/null 2>&1
echo "Patching FluidAudio (Swift 5 mode)..."
python3 Scripts/patch_fluidaudio.py
if [[ $? -ne 0 ]]; then
    echo "FluidAudio patch failed!"
    exit 1
fi

# Build the app
echo "Building WhisperForge..."
BUILD_OUTPUT=$(xcodebuild -scheme WhisperForge -configuration Debug -jobs 8 -derivedDataPath build -quiet -destination 'platform=macOS,arch=arm64' -skipPackagePluginValidation -skipMacroValidation -UseModernBuildSystem=YES -clonedSourcePackagesDirPath SourcePackages -skipUnavailableActions CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO OTHER_CODE_SIGN_FLAGS="--entitlements WhisperForge/WhisperForge.entitlements" build 2>&1)

# sudo gem install xcpretty
if command -v xcpretty &> /dev/null
then
    echo "$BUILD_OUTPUT" | xcpretty --simple --color
else
    echo "$BUILD_OUTPUT"
fi

# Check if build output contains BUILD FAILED or if the command failed
if [[ $? -eq 0 ]] && [[ ! "$BUILD_OUTPUT" =~ "BUILD FAILED" ]]; then
    echo "Building successful!"
    if $JUST_BUILD; then
        exit 0
    fi
    echo "Starting the app..."
    # Remove quarantine attribute if exists
    xattr -d com.apple.quarantine ./build/Build/Products/Debug/WhisperForge.app 2>/dev/null || true
    # Run the app and show logs
    ./build/Build/Products/Debug/WhisperForge.app/Contents/MacOS/WhisperForge
else
    echo "Build failed!"
    exit 1
fi 