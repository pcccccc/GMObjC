#!/bin/bash
set -e

# 获取脚本所在目录的父目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRAMEWORKS_DIR="$PROJECT_DIR/Frameworks"

echo "🔧 初始化项目..."
echo "📁 项目目录: $PROJECT_DIR"
echo "📁 Frameworks 目录: $FRAMEWORKS_DIR"

# 检查目录是否存在
if [ ! -d "$FRAMEWORKS_DIR" ]; then
    echo "❌ Frameworks 目录不存在: $FRAMEWORKS_DIR"
    exit 1
fi

cd "$FRAMEWORKS_DIR"

# 解压所有 xcframework.zip
shopt -s nullglob
zip_files=(*.xcframework.zip)

if [ ${#zip_files[@]} -eq 0 ]; then
    echo "⚠️  没有找到 .xcframework.zip 文件"
    exit 0
fi

for zip_file in "${zip_files[@]}"; do
    framework_name="${zip_file%.zip}"
    
    if [ ! -d "$framework_name" ]; then
        echo "📦 解压 $zip_file..."
        unzip -q "$zip_file"
    else
        echo "✓ $framework_name 已存在，跳过"
    fi
done

echo "✅ 初始化完成！"
