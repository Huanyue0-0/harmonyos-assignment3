#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把工程目录打包成交付 ZIP。

为什么不用系统 `zip` 命令：macOS 自带的 Info-ZIP 3.0 在写入含中文的文件名时
不会设置 UTF-8 标志位（bit 11），在 Windows/其它工具解压会出现乱码文件名。
`zipfile` 模块对非 ASCII 文件名会自动写入 UTF-8 标志位，跨平台解压正常。

用法：
    python3 scripts/zip_project.py <项目根目录> <输出zip路径>
"""

import os
import sys
import zipfile

# 需要排除的目录名（任意层级）
EXCLUDE_DIRS = {
    '.hvigor', 'oh_modules', 'node_modules', 'build', '.idea',
    '.cxx', '.preview', 'dist', 'spec', '.git',
}
# 需要排除的文件名
EXCLUDE_FILES = {'.DS_Store', 'local.properties'}

REQUIRED = [
    'build-profile.json5',
    'oh-package.json5',
    'hvigorfile.ts',
    'README.md',
    'AppScope/app.json5',
    'common/Index.ets',
    'features/Index.ets',
    'products/src/main/ets/pages/Index.ets',
    'products/src/main/module.json5',
    'docs/report/Assignment3_报告.docx',
    'docs/audit/code_audit_report.json',
    'docs/trace/skill-trace.log',
    'screenshots/README.md',
]


def collect(root):
    """自底向上遍历，返回需要打包的相对路径列表（已排序）。"""
    result = []
    for current, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in EXCLUDE_DIRS)
        for name in sorted(files):
            if name in EXCLUDE_FILES:
                continue
            absolute = os.path.join(current, name)
            relative = os.path.relpath(absolute, root)
            if relative == os.path.basename(__file__):
                continue
            result.append(relative)
    return sorted(result)


def main():
    if len(sys.argv) != 3:
        print('用法: python3 zip_project.py <项目根目录> <输出zip路径>')
        return 1
    root = os.path.abspath(sys.argv[1])
    zip_path = os.path.abspath(sys.argv[2])
    if not os.path.isfile(os.path.join(root, 'build-profile.json5')):
        print(f'错误：{root} 不是工程根目录（缺少 build-profile.json5）', file=sys.stderr)
        return 1

    os.makedirs(os.path.dirname(zip_path), exist_ok=True)
    if os.path.exists(zip_path):
        os.remove(zip_path)

    files = collect(root)
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as archive:
        for relative in files:
            archive.write(os.path.join(root, relative), arcname=relative)

    size = os.path.getsize(zip_path)
    print(f'==> 完成：{os.path.basename(zip_path)}（{size / 1024:.0f} KB，{len(files)} 个文件）')

    print('==> 关键文件检查：')
    missing = 0
    with zipfile.ZipFile(zip_path) as archive:
        names = set(archive.namelist())
    for item in REQUIRED:
        if item in names:
            print(f'    [OK]   {item}')
        else:
            print(f'    [MISS] {item}', file=sys.stderr)
            missing += 1
    if missing:
        print(f'==> 有 {missing} 个关键文件缺失，请检查排除规则', file=sys.stderr)
        return 2
    print('==> 打包成功（文件名已使用 UTF-8，跨平台解压不乱码）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
