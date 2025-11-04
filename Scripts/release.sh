#!/bin/bash
set -e

VERSION=$1

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRAMEWORKS_DIR="$PROJECT_DIR/Frameworks"

if [ -z "$VERSION" ]; then
    echo "❌ 用法: ./Scripts/release.sh v1.0.0"
    exit 1
fi

echo "🚀 准备发布版本 $VERSION..."

# 检查目录
if [ ! -d "$FRAMEWORKS_DIR" ]; then
    echo "❌ Frameworks 目录不存在"
    exit 1
fi

# 1. 压缩 xcframework
echo ""
echo "📦 压缩 frameworks..."
cd "$FRAMEWORKS_DIR"

shopt -s nullglob
frameworks=(*.xcframework)

if [ ${#frameworks[@]} -eq 0 ]; then
    echo "❌ 没有找到 .xcframework 目录"
    exit 1
fi

for framework in "${frameworks[@]}"; do
    echo "  压缩 $framework..."
    ditto -c -k --keepParent "$framework" "${framework}.zip"
done

echo "✅ 压缩完成"

# 2. 计算 checksums
echo ""
echo "📝 Checksums:"
echo "---"

for zip_file in *.xcframework.zip; do
    if [ -f "$zip_file" ]; then
        checksum=$(swift package compute-checksum "$zip_file")
        framework_name="${zip_file%.xcframework.zip}"
        echo "$framework_name: $checksum"
    fi
done

echo "---"
echo ""

# 3. 提示后续步骤
echo "📋 下一步："
echo "1. 创建 Git 标签: git tag $VERSION && git push origin $VERSION"
echo "2. 在 GitHub 创建 Release"
echo "3. 上传以下文件:"
for zip_file in *.xcframework.zip; do
    if [ -f "$zip_file" ]; then
        echo "   - $zip_file"
    fi
done
echo "4. 更新 Package.swift 中的 URL 和 checksum"
echo ""
echo "✨ 完成！"
