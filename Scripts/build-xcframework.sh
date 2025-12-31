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
        "macosx")
            ssl_lib="$OPENSSL_DIR/bin/MacOSX26.1-arm64.sdk/lib/libssl.a"
            crypto_lib="$OPENSSL_DIR/bin/MacOSX26.1-arm64.sdk/lib/libcrypto.a"
            ;;
    esac

    echo "$ssl_lib $crypto_lib"
}

# 构建单个平台
build_platform() {
    local sdk=$1
    local destination=$2
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

# iOS Simulator
if build_platform "iphonesimulator" "generic/platform=iOS Simulator"; then
    ARCHIVES+=("-framework" "$OUTPUT_DIR/archives/iphonesimulator.xcarchive/Products/Library/Frameworks/GMObjC.framework")
fi

# tvOS Device
if build_platform "appletvos" "generic/platform=tvOS"; then
    ARCHIVES+=("-framework" "$OUTPUT_DIR/archives/appletvos.xcarchive/Products/Library/Frameworks/GMObjC.framework")
fi

# tvOS Simulator
if build_platform "appletvsimulator" "generic/platform=tvOS Simulator"; then
    ARCHIVES+=("-framework" "$OUTPUT_DIR/archives/appletvsimulator.xcarchive/Products/Library/Frameworks/GMObjC.framework")
fi

# macOS
if build_platform "macosx" "generic/platform=macOS"; then
    ARCHIVES+=("-framework" "$OUTPUT_DIR/archives/macosx.xcarchive/Products/Library/Frameworks/GMObjC.framework")
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
