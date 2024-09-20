#!/bin/bash
######################################################
# 描述: 使用Brotli和gzip压缩特定文件类型的脚本
# 版本: 1.0
# 作者：https://junkai.cc
######################################################

# 文件权限、用户和组配置
USER=root
GROUP=root
CHMOD=644

# 时间戳
DT=$(date +"%d%m%y-%H%M%S")

# 获取脚本所在目录
SCRIPT_DIR=$(readlink -f $(dirname ${BASH_SOURCE[0]}))
echo "脚本所在目录: $SCRIPT_DIR"

# 日志目录，存放压缩日志
LOGDIR='/var/log/brotli'

# 定义需要压缩的文件类型
FILETYPES=("*.css" "*.js" "*.svg" "*.ttf")

# 最大文件大小（1MB），大于此值的文件不会被压缩
FILE_MINSIZE='1048576'

# Brotli 压缩等级
BROTLI_LEVEL=11
BROTLI_BINOPT="-q $BROTLI_LEVEL --force"

# 是否启用 gzip 压缩及其压缩等级
GZIP=y
GZIP_LEVEL=11

# 获取 CPU 核心数量
CPUS=$(grep -c "processor" /proc/cpuinfo)

# CMake 版本
CMAKE_MIN_VERSION="3.15"
CMAKE_TAR="cmake-3.26.4-linux-x86_64.tar.gz"
CMAKE_URL="https://cmake.org/files/v3.26/$CMAKE_TAR"
INSTALL_DIR="/usr/local"

# 检查 CMake 版本并进行安装
check_and_install_cmake() {
  echo "检查 CMake 版本..."
  
  if ! command -v cmake &> /dev/null; then
    echo "CMake 未安装，正在安装..."
    install_cmake
    return
  fi

  CMAKE_VERSION=$(cmake --version | head -n 1 | awk '{print $3}')
  echo "当前 CMake 版本: $CMAKE_VERSION"

  # 比较版本号，如果当前版本小于最低要求版本，则安装新的 CMake
  if [[ $(printf '%s\n' "$CMAKE_MIN_VERSION" "$CMAKE_VERSION" | sort -V | head -n1) != "$CMAKE_MIN_VERSION" ]]; then
    echo "CMake 版本低于 $CMAKE_MIN_VERSION，正在安装..."
    install_cmake
  else
    echo "CMake 版本满足要求"
  fi
}

# 安装 CMake 并更新路径
install_cmake() {
  echo "下载并安装 CMake..."
  
  # 如果 CMake 文件已经存在，先删除
  if [[ -f "$CMAKE_TAR" ]]; then
    echo "删除已存在的 CMake 文件..."
    rm -f "$CMAKE_TAR"
  fi

  # 下载 CMake
  wget "$CMAKE_URL"
  if [[ $? -ne 0 ]]; then
    echo "CMake 下载失败"
    exit 1
  fi

  # 如果解压目录已经存在，先删除
  if [[ -d "cmake-3.26.4-linux-x86_64" ]]; then
    echo "删除已存在的 CMake 解压目录..."
    rm -rf "cmake-3.26.4-linux-x86_64"
  fi

  # 解压 CMake
  tar -zxvf "$CMAKE_TAR"
  if [[ $? -ne 0 ]]; then
    echo "解压 CMake 失败"
    exit 1
  fi

  # 安装 CMake 到指定目录
  sudo cp -r cmake-3.26.4-linux-x86_64/* "$INSTALL_DIR/"
  if [[ $? -ne 0 ]]; then
    echo "CMake 安装失败"
    exit 1
  fi

  # 更新路径
  export PATH="$INSTALL_DIR/bin:$PATH"
  echo "CMake 安装完成"
  cmake --version
}



# 检查 Brotli 是否需要安装
install_brotli() {
    
      echo "检查 Brotli 是否已经安装..."

  # 检查是否已经安装 Brotli 且可执行
  if command -v brotli &> /dev/null; then
    echo "Brotli 已经安装且可执行，跳过安装步骤。"
      BROTLI_BIN='/usr/local/bin/brotli'
  BROTLI_BINOPT="-q $BROTLI_LEVEL --force"
    return
  fi

  echo "正在安装 Brotli..."

  # 设置 Brotli 源码目录
  BROTLI_SRC_DIR="/JK/sh/brotli"

  # 检查目录是否存在
  if [ -d "$BROTLI_SRC_DIR" ]; then
    echo "Brotli 目录已存在，执行更新操作..."
    cd "$BROTLI_SRC_DIR"
    git pull
    if [[ $? -ne 0 ]]; then
      echo "更新 Brotli 仓库失败"
      exit 1
    fi
  else
    # 克隆 Brotli 仓库
    echo "克隆 Brotli 仓库..."
    git clone https://github.com/google/brotli.git "$BROTLI_SRC_DIR"
    if [[ $? -ne 0 ]]; then
      echo "克隆 Brotli 仓库失败"
      exit 1
    fi
    cd "$BROTLI_SRC_DIR"
  fi

  # 删除旧的构建目录，确保干净构建
  if [ -d "out" ]; then
    rm -rf out
  fi

  # 重新创建构建目录
  mkdir -p out && cd out

  # 配置 Brotli 并确保没有旧的库文件冲突
  cmake ..
  if [[ $? -ne 0 ]]; then
    echo "CMake 配置失败"
    exit 1
  fi

  # 编译 Brotli
  make -j$(nproc)
  if [[ $? -ne 0 ]]; then
    echo "Brotli 构建失败"
    exit 1
  fi

  # 安装 Brotli
  sudo make install
  if [[ $? -ne 0 ]]; then
    echo "Brotli 安装失败"
    exit 1
  fi

  # 检查 Brotli 是否安装成功
  if [ -f /usr/local/bin/brotli ]; then
    ls -lah /usr/local/bin/brotli
  else
    echo "Brotli 安装失败"
    exit 1
  fi

  # 确保库路径正确
  export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
  echo "Brotli 安装完成"
  BROTLI_BIN='/usr/local/bin/brotli'
  BROTLI_BINOPT="-q $BROTLI_LEVEL --force"
}

######################################################
# 主流程
# 检查 CMake 版本并安装
check_and_install_cmake

# 安装 Brotli
install_brotli 


# 检测并安装 pigz
if [ ! -f /usr/bin/pigz ]; then
  echo
  echo "/usr/bin/pigz 未找到"
  echo "正在从 YUM 仓库安装 pigz..."
  echo
  sleep 3
  yum -q -y install pigz
  
  # 检查 pigz 是否安装成功
  if [ ! -f /usr/bin/pigz ]; then
    echo "/usr/bin/pigz 安装失败，依然未找到"
    echo "将使用 gzip 作为替代"
    GZIP_PIGZ='n'
    GZIP_BIN='/usr/bin/gzip'
    GZIP_BINOPT="-${GZIP_LEVEL}"
  fi
fi

# 根据 CPU 核心数设置 gzip 使用 pigz 或 gzip
if [ -f /usr/bin/pigz ] && [ "$CPUS" -ge 2 ]; then
  GZIP_PIGZ='y'
  GZIP_BIN='/usr/bin/pigz'
  GZIP_BINOPT="-${GZIP_LEVEL}k -f"
else
  GZIP_PIGZ='n'
  GZIP_BIN='/usr/bin/gzip'
  GZIP_BINOPT="-${GZIP_LEVEL}"
fi


# 如果日志目录不存在，则创建
if [ ! -d "$LOGDIR" ]; then
  mkdir -p "$LOGDIR"
fi

# 如果配置文件存在，则加载配置文件
if [ -f "$SCRIPT_DIR/brotli-config.ini" ]; then
  source "$SCRIPT_DIR/brotli-config.ini"
fi

# 展示文件，按文件名排序并显示大小
display_files() {
  DISPLAY=$1
  if [[ "$DISPLAY" = 'display' ]]; then
    echo "文件列表"
    /usr/bin/find $DIR_PATH -type f \( -iname '*.js.br' -o -iname '*.js.gz' -o -iname '*.css.br' -o -iname '*.css.gz' -o -iname '*.svg.br' -o -iname '*.svg.gz' -o -iname '*.ttf.br' -o -iname '*.ttf.gz'  -o -iname '*.js'  -o -iname '*.css'  -o -iname '*.svg'  -o -iname '*.ttf' \) -print0 | sort -z | while read -d $'\0' f;
    do
      FILESIZE=$(stat -c%s "$f")
      echo "文件: $f | $FILESIZE 字节"
    done
  fi
}

# 压缩函数
brotli_compress() {
  BROTLI_CLEAN=$1
  for filematch in "${FILETYPES[@]}"
  do
    /usr/bin/find $DIR_PATH -type f -iname "$filematch" -print0 | while read -d $'\0' f;
    do
      DETECT_EXT="${f##*.}"
      FILESIZE=$(stat -c%s "$f")
      
      # 清理操作
      if [[ "$BROTLI_CLEAN" = 'clean' ]]; then
        if [ -f "${f}.br" ]; then
          echo "删除文件: ${f}.br"
          rm -rf "${f}.br"
        fi
        if [ -f "${f}.gz" ]; then
          echo "删除文件: ${f}.gz"
          rm -rf "${f}.gz"
        fi
        
      # 压缩操作
      elif [[ "$FILESIZE" -le "$FILE_MINSIZE" ]]; then
        {
          # Brotli 压缩
          $BROTLI_BIN $BROTLI_BINOPT "${f}" --output="${f}.br"
          chown ${USER}:${GROUP} "${f}.br"
          chmod $CHMOD "${f}.br"
          BRCOMP_FILESIZE=$(stat -c%s "${f}.br")
          echo "[.br]: $f | 原文件: $FILESIZE 字节 |  (.br): $BRCOMP_FILESIZE 字节"
          
         
          # GZIP 压缩（如果启用）
          if [[ "$GZIP" = [Yy] ]]; then
            $GZIP_BIN $GZIP_BINOPT "${f}"
            GZCOMP_FILESIZE=$(stat -c%s "${f}.gz")
            echo "[.gz]: $f | 原文件: $FILESIZE 字节 |  (.gz): $GZCOMP_FILESIZE 字节"
            chown ${USER}:${GROUP} "${f}.gz"
            chmod $CHMOD "${f}.gz"
          fi
        } &
      fi
    done
  done
  wait  # 等待所有并行任务完成
}


######################################################
# 脚本开始执行部分
######################################################
DIR_PATH=$1
CLEAN=$2

# 根据输入参数执行不同操作
if [[ -z "$DIR_PATH" && -z "$CLEAN" ]] || [[ -z "$DIR_PATH" && ! -z "$CLEAN" ]]; then
  echo "用法:"
  echo "$0 /path/to/parent/directory"
  echo "$0 /path/to/parent/directory clean"
  echo "$0 /path/to/parent/directory display"
elif [[ -d "$DIR_PATH" && "$CLEAN" = 'clean' ]]; then
  brotli_compress clean 2>&1 | tee ${LOGDIR}/brotli.sh_clean_${DT}.log
elif [[ -d "$DIR_PATH" && "$CLEAN" = 'display' ]]; then
  display_files display 2>&1 | tee ${LOGDIR}/brotli.sh_display_${DT}.log
else
  brotli_compress 2>&1 | tee ${LOGDIR}/brotli.sh_${DT}.log
fi