# brgzSH

## 简介

此脚本用于自动化压缩特定类型的文件（如 `.css`、`.js`、`.svg` 和 `.ttf`），使用 Brotli 和 GZIP 压缩算法。它会检查并安装所需的 CMake 和 Brotli 工具，并支持文件清理和显示功能。

## 作用

- **自动化压缩**：使用 Brotli 和 GZIP 压缩文件，减少文件大小以提高网页加载速度。
- **版本检查**：确保系统中安装的 CMake 版本满足最低要求。
- **文件管理**：提供清理功能以删除旧的压缩文件，并能够显示压缩文件的列表和大小。
- **日志记录**：将操作记录到日志文件中，方便后续查阅。

## 如何操作

1. **克隆或下载代码**：
   ```bash
   git clone https://github.com/JunKai-cc/brgzSH.git
   cd /brgzSH/A
   
   chmod +x brotli.sh

   # 单文件压缩
   ./brgzSH.sh /path/to/your/directory/c.js

   # 目录压缩
   ./brgzSH.sh /path/to/your/directory

   # 清理.br .gz文件
   ./brgzSH.sh /path/to/your/directory clean

   # 显示文件及其大小
   ./brgzSH.sh /path/to/your/directory display
