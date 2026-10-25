#!/usr/bin/env bash
# 交付打包脚本（Assignment 3 差旅报销小程序）
# 用法：bash scripts/package.sh [输出目录]      默认输出到项目根
# 产物：<输出目录>/Assignment3_TeamX_StudentID1_StudentID2.zip
#
# 排除规则：.hvigor / oh_modules / node_modules / build / .idea / .cxx /
#           .preview / dist / spec / .git / .DS_Store / local.properties
# 归档实现：scripts/zip_project.py（使用 zipfile 写入 UTF-8 文件名，
#           避免 macOS 自带 zip 对中文文件名不置 UTF-8 标志位导致解压乱码）

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${PROJECT_ROOT}}"
ZIP_NAME="Assignment3_TeamX_StudentID1_StudentID2.zip"
ZIP_PATH="${OUTPUT_DIR}/${ZIP_NAME}"

if [ ! -f "${PROJECT_ROOT}/build-profile.json5" ]; then
  echo "错误：${PROJECT_ROOT} 不是工程根目录（缺少 build-profile.json5）" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "==> 打包：${ZIP_PATH}"
python3 "${PROJECT_ROOT}/scripts/zip_project.py" "${PROJECT_ROOT}" "${ZIP_PATH}"

echo "==> 提交前请把包名中的 TeamX / StudentID1 / StudentID2 替换为真实信息"
