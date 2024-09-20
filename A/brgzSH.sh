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

# brotli路径
BROTLI_BIN="$SCRIPT_DIR/brotli"

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
