#!/bin/bash
#
# 构建 GMObjC.xcframework（包含 OpenSSL 3.6.0）
# 直接编译源码，静态链接 OpenSSL
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OPENSSL_DIR="/Users/pangchong/Desktop/Git/openssl-apple"
OUTPUT_DIR="$PROJECT_DIR/build"
FRAMEWORKS_DIR="$PROJECT_DIR/Frameworks"
SOURCE_DIR="$PROJECT_DIR/GMObjC"

echo "==========================================="
echo "构建 GMObjC.xcframework (OpenSSL 3.6.0)"
echo "==========================================="
echo ""
echo "项目目录: $PROJECT_DIR"
echo "OpenSSL 目录: $OPENSSL_DIR"
echo "输出目录: $OUTPUT_DIR"
echo ""

# 清理
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/archives"

# GMObjC 源文件
SOURCES=(
    "$SOURCE_DIR/GMDoctor.m"
    "$SOURCE_DIR/GMSm2Bio.m"
    "$SOURCE_DIR/GMSm2Utils.m"
    "$SOURCE_DIR/GMSm3Utils.m"
    "$SOURCE_DIR/GMSm4Utils.m"
    "$SOURCE_DIR/GMSmUtils.m"
)

# 构建单个平台
build_platform() {
    local sdk=$1
    local arch=$2
    local platform=$3
    local min_version=$4
    local openssl_sdk=$5

    local framework_dir="$OUTPUT_DIR/archives/$platform-$arch/GMObjC.framework"
    local ssl_lib="$OPENSSL_DIR/bin/$openssl_sdk/lib/libssl.a"
    local crypto_lib="$OPENSSL_DIR/bin/$openssl_sdk/lib/libcrypto.a"

    echo ""
    echo "🔨 构建 $platform $arch..."

    if [ ! -f "$ssl_lib" ] || [ ! -f "$crypto_lib" ]; then
        echo "  ⚠️  跳过 (缺少 OpenSSL: $openssl_sdk)"
        return 1
    fi

    mkdir -p "$framework_dir/Headers"
    mkdir -p "$framework_dir/Modules"

    # 编译对象文件 (ObjC 使用默认可见性)
    local objs=()
    for src in "${SOURCES[@]}"; do
        local obj="$OUTPUT_DIR/archives/$platform-$arch/$(basename "$src" .m).o"
        xcrun -sdk $sdk clang -c \
            -arch $arch \
            -m${platform}-version-min=$min_version \
            -I"$SOURCE_DIR" \
            -I"$OPENSSL_DIR/include" \
            -fobjc-arc \
            -fmodules \
            -Wno-deprecated-declarations \
            -o "$obj" "$src"
        objs+=("$obj")
    done

    # 提取 OpenSSL 静态库
    local openssl_obj_dir="$OUTPUT_DIR/archives/$platform-$arch/openssl_objs"
    mkdir -p "$openssl_obj_dir"

    cd "$openssl_obj_dir"
    ar -x "$ssl_lib"
    ar -x "$crypto_lib"
    cd - > /dev/null

    # 创建导出符号列表文件
    local exports_file="$OUTPUT_DIR/archives/$platform-$arch/exports.txt"
    cat > "$exports_file" << 'EXPORTS'
_OBJC_CLASS_$_GMDoctor
_OBJC_METACLASS_$_GMDoctor
_OBJC_CLASS_$_GMSm2Bio
_OBJC_METACLASS_$_GMSm2Bio
_OBJC_CLASS_$_GMSm2Utils
_OBJC_METACLASS_$_GMSm2Utils
_OBJC_CLASS_$_GMSm3Utils
_OBJC_METACLASS_$_GMSm3Utils
_OBJC_CLASS_$_GMSm4Utils
_OBJC_METACLASS_$_GMSm4Utils
_OBJC_CLASS_$_GMSmUtils
_OBJC_METACLASS_$_GMSmUtils
EXPORTS

    # 创建动态库
    # -fvisibility=hidden 用于链接阶段隐藏 OpenSSL 符号
    # -exported_symbols_list 导出 GMObjC 的类符号
    xcrun -sdk $sdk clang \
        -arch $arch \
        -m${platform}-version-min=$min_version \
        -dynamiclib \
        -install_name @rpath/GMObjC.framework/GMObjC \
        -Xlinker -rpath -Xlinker @executable_path/Frameworks \
        -Xlinker -rpath -Xlinker @loader_path/Frameworks \
        -fvisibility=hidden \
        -exported_symbols_list "$exports_file" \
        -framework Foundation \
        -framework Security \
        -o "$framework_dir/GMObjC" \
        "${objs[@]}" \
        "$openssl_obj_dir"/*.o

    # 复制头文件
    cp "$SOURCE_DIR"/*.h "$framework_dir/Headers/"

    # 创建 Info.plist
    cat > "$framework_dir/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GMObjC</string>
    <key>CFBundleIdentifier</key>
    <string>com.pcccccc.GMObjC</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>GMObjC</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>$min_version</string>
</dict>
</plist>
EOF

    # 创建 module.modulemap
    cat > "$framework_dir/Modules/module.modulemap" << 'EOF'
framework module GMObjC {
    umbrella header "GMObjC.h"
    export *
    module * { export * }
}
EOF

    echo "  ✓ $platform $arch 完成"
    return 0
}

# 构建各平台
echo ""
echo "开始构建各平台..."

# iOS Device
build_platform "iphoneos" "arm64" "ios" "12.0" "iPhoneOS26.1-arm64.sdk"

# iOS Simulator
build_platform "iphonesimulator" "arm64" "ios-simulator" "12.0" "iPhoneSimulator26.1-arm64.sdk"

# tvOS Device
build_platform "appletvos" "arm64" "tvos" "12.0" "AppleTVOS26.1-arm64.sdk"

# tvOS Simulator
build_platform "appletvsimulator" "arm64" "tvos-simulator" "12.0" "AppleTVSimulator26.1-arm64.sdk"

# macOS
build_platform "macosx" "arm64" "macos" "10.13" "MacOSX26.1-arm64.sdk"

# 创建 xcframework
echo ""
echo "📦 创建 xcframework..."

FRAMEWORK_ARGS=()

for dir in "$OUTPUT_DIR/archives"/*/GMObjC.framework; do
    if [ -d "$dir" ]; then
        FRAMEWORK_ARGS+=("-framework" "$dir")
    fi
done

if [ ${#FRAMEWORK_ARGS[@]} -eq 0 ]; then
    echo "❌ 没有成功构建任何平台"
    exit 1
fi

xcodebuild -create-xcframework \
    "${FRAMEWORK_ARGS[@]}" \
    -output "$OUTPUT_DIR/GMObjC.xcframework"

echo ""
echo "==========================================="
echo "✅ 构建完成!"
echo "==========================================="
echo ""
echo "输出: $OUTPUT_DIR/GMObjC.xcframework"
echo ""
echo "下一步:"
echo "1. 复制新的 framework:"
echo "   cp -r $OUTPUT_DIR/GMObjC.xcframework $FRAMEWORKS_DIR/"
echo ""
echo "2. 删除 openssl.xcframework (已内置到 GMObjC 中):"
echo "   rm -rf $FRAMEWORKS_DIR/openssl.xcframework"
echo ""
echo "3. 更新 Package.swift，移除 openssl 依赖"
echo ""
