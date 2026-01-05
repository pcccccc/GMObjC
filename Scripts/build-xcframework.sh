#!/bin/bash
#
# 构建 GMObjC.xcframework
# 静态链接 OpenSSL 并隐藏符号，避免与 FFmpegKit 冲突
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OPENSSL_DIR="/Users/pangchong/Desktop/Git/openssl-apple"
OUTPUT_DIR="$PROJECT_DIR/build"
FRAMEWORKS_DIR="$PROJECT_DIR/Frameworks"

echo "==========================================="
echo "构建 GMObjC.xcframework"
echo "静态链接 OpenSSL + 符号隐藏"
echo "==========================================="
echo ""
echo "项目目录: $PROJECT_DIR"
echo "OpenSSL 目录: $OPENSSL_DIR"
echo "输出目录: $OUTPUT_DIR"
echo ""

# 检查 OpenSSL 静态库 (编译后在 bin/ 目录)
if [ ! -d "$OPENSSL_DIR/bin" ]; then
    echo "❌ OpenSSL 静态库不存在: $OPENSSL_DIR/bin"
    echo "请先编译 OpenSSL:"
    echo "  cd $OPENSSL_DIR && ./build-libssl.sh --version=1.1.1w"
    exit 1
fi

# 清理
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 通用构建设置 - 关键：隐藏 OpenSSL 符号
COMMON_BUILD_SETTINGS=(
    "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
    "SKIP_INSTALL=NO"
    "OTHER_CFLAGS=-fvisibility=hidden"
    "GCC_SYMBOLS_PRIVATE_EXTERN=YES"
    "HEADER_SEARCH_PATHS=$OPENSSL_DIR/include"
    "CODE_SIGNING_ALLOWED=NO"
    "CODE_SIGN_IDENTITY=-"
    "IPHONEOS_DEPLOYMENT_TARGET=12.0"
    "TVOS_DEPLOYMENT_TARGET=12.0"
    "MACOSX_DEPLOYMENT_TARGET=10.13"
)

# 获取对应平台的 OpenSSL 库 (在 bin/{SDK}.sdk/lib/ 目录)
get_openssl_libs() {
    local platform=$1
    local ssl_lib crypto_lib

    case "$platform" in
        "iphoneos")
            # iOS arm64 设备
            ssl_lib="$OPENSSL_DIR/bin/iPhoneOS26.1-arm64.sdk/lib/libssl.a"
            crypto_lib="$OPENSSL_DIR/bin/iPhoneOS26.1-arm64.sdk/lib/libcrypto.a"
            ;;
        "iphonesimulator")
            # iOS 模拟器 arm64 (M1/M2)
            ssl_lib="$OPENSSL_DIR/bin/iPhoneSimulator26.1-arm64.sdk/lib/libssl.a"
            crypto_lib="$OPENSSL_DIR/bin/iPhoneSimulator26.1-arm64.sdk/lib/libcrypto.a"
            ;;
        "appletvos")
            ssl_lib="$OPENSSL_DIR/bin/AppleTVOS26.1-arm64.sdk/lib/libssl.a"
            crypto_lib="$OPENSSL_DIR/bin/AppleTVOS26.1-arm64.sdk/lib/libcrypto.a"
            ;;
        "appletvsimulator")
            ssl_lib="$OPENSSL_DIR/bin/AppleTVSimulator26.1-arm64.sdk/lib/libssl.a"
            crypto_lib="$OPENSSL_DIR/bin/AppleTVSimulator26.1-arm64.sdk/lib/libcrypto.a"
            ;;
        "macosx-arm64")
            ssl_lib="$OPENSSL_DIR/bin/MacOSX26.1-arm64.sdk/lib/libssl.a"
            crypto_lib="$OPENSSL_DIR/bin/MacOSX26.1-arm64.sdk/lib/libcrypto.a"
            ;;
        "macosx-x86_64")
            ssl_lib="$OPENSSL_DIR/bin/MacOSX26.1-x86_64.sdk/lib/libssl.a"
            crypto_lib="$OPENSSL_DIR/bin/MacOSX26.1-x86_64.sdk/lib/libcrypto.a"
            ;;
    esac

    echo "$ssl_lib $crypto_lib"
}

# 构建单个平台
build_platform() {
    local sdk=$1
    local destination=$2
    local extra_settings=$3
    local archive_path="$OUTPUT_DIR/archives/$sdk.xcarchive"

    echo ""
    echo "🔨 构建 $sdk..."

    local libs=($(get_openssl_libs "$sdk"))
    local ssl_lib="${libs[0]}"
    local crypto_lib="${libs[1]}"

    if [ ! -f "$ssl_lib" ] || [ ! -f "$crypto_lib" ]; then
        echo "⚠️  跳过 $sdk (缺少 OpenSSL 库)"
        return 1
    fi

    xcodebuild archive \
        -project "$PROJECT_DIR/GMObjC.xcodeproj" \
        -scheme "GMObjC" \
        -destination "$destination" \
        -archivePath "$archive_path" \
        "${COMMON_BUILD_SETTINGS[@]}" \
        "OTHER_LDFLAGS=-force_load $ssl_lib -force_load $crypto_lib" \
        $extra_settings \
        -quiet

    if [ -d "$archive_path" ]; then
        echo "  ✓ $sdk 完成"
        return 0
    else
        echo "  ✗ $sdk 失败"
        return 1
    fi
}

# 构建各平台
echo ""
echo "开始构建各平台..."

ARCHIVES=()

# iOS Device
if build_platform "iphoneos" "generic/platform=iOS"; then
    ARCHIVES+=("-framework" "$OUTPUT_DIR/archives/iphoneos.xcarchive/Products/Library/Frameworks/GMObjC.framework")
fi

# iOS Simulator (arm64 only for Apple Silicon)
if build_platform "iphonesimulator" "generic/platform=iOS Simulator" "ARCHS=arm64 ONLY_ACTIVE_ARCH=NO"; then
    ARCHIVES+=("-framework" "$OUTPUT_DIR/archives/iphonesimulator.xcarchive/Products/Library/Frameworks/GMObjC.framework")
fi

# tvOS Device
if build_platform "appletvos" "generic/platform=tvOS"; then
    ARCHIVES+=("-framework" "$OUTPUT_DIR/archives/appletvos.xcarchive/Products/Library/Frameworks/GMObjC.framework")
fi

# tvOS Simulator (arm64 only for Apple Silicon)
if build_platform "appletvsimulator" "generic/platform=tvOS Simulator" "ARCHS=arm64 ONLY_ACTIVE_ARCH=NO"; then
    ARCHIVES+=("-framework" "$OUTPUT_DIR/archives/appletvsimulator.xcarchive/Products/Library/Frameworks/GMObjC.framework")
fi

# macOS (Universal: arm64 + x86_64)
echo ""
echo "🔨 构建 macOS Universal (arm64 + x86_64)..."
MACOS_ARM64_SUCCESS=false
MACOS_X86_64_SUCCESS=false

# 构建 macOS arm64
if build_platform "macosx-arm64" "generic/platform=macOS" "ARCHS=arm64 ONLY_ACTIVE_ARCH=NO"; then
    MACOS_ARM64_SUCCESS=true
fi

# 构建 macOS x86_64
if build_platform "macosx-x86_64" "generic/platform=macOS" "ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO"; then
    MACOS_X86_64_SUCCESS=true
fi

# 合并为 Universal Binary
if [ "$MACOS_ARM64_SUCCESS" = true ] && [ "$MACOS_X86_64_SUCCESS" = true ]; then
    echo "  📦 合并 macOS Universal Binary..."
    MACOS_UNIVERSAL_DIR="$OUTPUT_DIR/archives/macosx-universal"
    mkdir -p "$MACOS_UNIVERSAL_DIR/GMObjC.framework/Versions/A/Headers"
    mkdir -p "$MACOS_UNIVERSAL_DIR/GMObjC.framework/Versions/A/Modules"
    mkdir -p "$MACOS_UNIVERSAL_DIR/GMObjC.framework/Versions/A/Resources"

    # 使用 lipo 合并二进制
    lipo -create \
        "$OUTPUT_DIR/archives/macosx-arm64.xcarchive/Products/Library/Frameworks/GMObjC.framework/GMObjC" \
        "$OUTPUT_DIR/archives/macosx-x86_64.xcarchive/Products/Library/Frameworks/GMObjC.framework/GMObjC" \
        -output "$MACOS_UNIVERSAL_DIR/GMObjC.framework/Versions/A/GMObjC"

    # 复制 Headers、Modules、Resources (从 arm64 版本)
    cp -r "$OUTPUT_DIR/archives/macosx-arm64.xcarchive/Products/Library/Frameworks/GMObjC.framework/Headers/"* \
        "$MACOS_UNIVERSAL_DIR/GMObjC.framework/Versions/A/Headers/"
    cp -r "$OUTPUT_DIR/archives/macosx-arm64.xcarchive/Products/Library/Frameworks/GMObjC.framework/Modules/"* \
        "$MACOS_UNIVERSAL_DIR/GMObjC.framework/Versions/A/Modules/"

    # 复制 Info.plist
    if [ -f "$OUTPUT_DIR/archives/macosx-arm64.xcarchive/Products/Library/Frameworks/GMObjC.framework/Resources/Info.plist" ]; then
        cp "$OUTPUT_DIR/archives/macosx-arm64.xcarchive/Products/Library/Frameworks/GMObjC.framework/Resources/Info.plist" \
            "$MACOS_UNIVERSAL_DIR/GMObjC.framework/Versions/A/Resources/"
    elif [ -f "$OUTPUT_DIR/archives/macosx-arm64.xcarchive/Products/Library/Frameworks/GMObjC.framework/Info.plist" ]; then
        cp "$OUTPUT_DIR/archives/macosx-arm64.xcarchive/Products/Library/Frameworks/GMObjC.framework/Info.plist" \
            "$MACOS_UNIVERSAL_DIR/GMObjC.framework/Versions/A/Resources/"
    fi

    # 创建版本化结构的符号链接
    cd "$MACOS_UNIVERSAL_DIR/GMObjC.framework/Versions"
    ln -sf A Current
    cd "$MACOS_UNIVERSAL_DIR/GMObjC.framework"
    ln -sf Versions/Current/GMObjC GMObjC
    ln -sf Versions/Current/Headers Headers
    ln -sf Versions/Current/Modules Modules
    ln -sf Versions/Current/Resources Resources

    ARCHIVES+=("-framework" "$MACOS_UNIVERSAL_DIR/GMObjC.framework")
    echo "  ✓ macOS Universal 完成"
elif [ "$MACOS_ARM64_SUCCESS" = true ]; then
    echo "  ⚠️  仅 arm64 成功，使用单架构"
    ARCHIVES+=("-framework" "$OUTPUT_DIR/archives/macosx-arm64.xcarchive/Products/Library/Frameworks/GMObjC.framework")
elif [ "$MACOS_X86_64_SUCCESS" = true ]; then
    echo "  ⚠️  仅 x86_64 成功，使用单架构"
    ARCHIVES+=("-framework" "$OUTPUT_DIR/archives/macosx-x86_64.xcarchive/Products/Library/Frameworks/GMObjC.framework")
fi

# 创建 xcframework
if [ ${#ARCHIVES[@]} -eq 0 ]; then
    echo ""
    echo "❌ 没有成功构建任何平台"
    exit 1
fi

echo ""
echo "📦 创建 xcframework..."

xcodebuild -create-xcframework \
    "${ARCHIVES[@]}" \
    -output "$OUTPUT_DIR/GMObjC.xcframework"

echo ""
echo "==========================================="
echo "✅ 构建完成!"
echo "==========================================="
echo ""
echo "输出: $OUTPUT_DIR/GMObjC.xcframework"
echo ""
echo "下一步:"
echo "1. 备份原有 framework:"
echo "   mv $FRAMEWORKS_DIR/GMObjC.xcframework $FRAMEWORKS_DIR/GMObjC.xcframework.bak"
echo ""
echo "2. 复制新的 framework:"
echo "   cp -r $OUTPUT_DIR/GMObjC.xcframework $FRAMEWORKS_DIR/"
echo ""
echo "3. 删除 openssl.xcframework (已内置到 GMObjC 中):"
echo "   rm -rf $FRAMEWORKS_DIR/openssl.xcframework"
echo ""
echo "4. 更新 Package.swift，移除 openssl 依赖"
echo ""
