#!/bin/bash
set -euo pipefail

# 用于在 buildroot 中对 openwrt 源做定制化修改
# 说明：把此脚本放在仓库根目录（与 openwrt 源同级），构建前会执行

# helper: backup file if exists
backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    cp -a "$f" "${f}.bak_$(date +%s)"
  fi
}

# 1) 修改默认 LAN IP 为 192.168.2.1（更有针对性地替换 config_generate 中的 LAN 相关行）
CFG_GEN="package/base-files/files/bin/config_generate"
if [ -f "$CFG_GEN" ]; then
  backup_file "$CFG_GEN"
  # 更有针对性：替换涉及 '192.168.1.1' 的行（通常是 uci set network.lan.ipaddr='192.168.1.1'）
  sed -i "s/\(ipaddr='\?\)192\.168\.1\.1\('\?\)/\1192.168.2.1\2/g" "$CFG_GEN"
  echo "Updated default LAN IP in $CFG_GEN"
else
  echo "Warning: $CFG_GEN not found, skipping IP change"
fi

# 2) 修改默认主机名为 K2P-Pro（针对 config_generate 中设置 hostname 的语句）
if [ -f "$CFG_GEN" ]; then
  backup_file "$CFG_GEN"
  # 替换与 hostname 设置相关的常见形式
  sed -i "s/\(set system.@system\[0\].hostname=\)\(['\"]\?\)OpenWrt\(['\"]\?\)/\1'K2P-Pro'/g" "$CFG_GEN" || true
  # 兜底：如果仍有 "hostname 'OpenWrt'" 的形式，再替换
  sed -i "s/\(hostname=['\"]\?\)OpenWrt\(['\"]\?\)/\1K2P-Pro\2/g" "$CFG_GEN" || true
  echo "Updated default hostname in $CFG_GEN (if matching patterns were found)"
fi

# 3) 强制默认语言为中文（更稳妥的方式：创建 /etc/config/luci 来指定 lang）
LUCICONF_DIR="package/base-files/files/etc"
mkdir -p "$LUCICONF_DIR"
LUCICONF="$LUCICONF_DIR/config/luci"
if [ ! -f "$LUCICONF" ]; then
  mkdir -p "$(dirname "$LUCICONF")"
  cat > "$LUCICONF" <<'EOF'
config core 'main'
	option lang 'zh-cn'
EOF
  echo "Created $LUCICONF to set LuCI default language to zh-cn"
else
  backup_file "$LUCICONF"
  # 如果已有 lang，替换；否则追加
  if grep -q "option lang" "$LUCICONF"; then
    sed -i "s/option lang .*/option lang 'zh-cn'/" "$LUCICONF"
  else
    cat >> "$LUCICONF" <<'EOF'

# Set default LuCI language
config core 'main'
	option lang 'zh-cn'
EOF
  fi
  echo "Updated $LUCICONF to set default language to zh-cn"
fi

# 4) 设置 root 无密码（可选 - 高风险）。默认行为：不改动密码，若确实要清空请设置 CLEAR_ROOT_PASS=1
CLEAR_ROOT_PASS="${CLEAR_ROOT_PASS:-0}"
SHADOW="package/base-files/files/etc/shadow"
if [ -f "$SHADOW" ]; then
  backup_file "$SHADOW"
  if [ "$CLEAR_ROOT_PASS" -eq 1 ]; then
    # 把 root 的密码字段设为空： root::0:99999:7:::
    # 注意：这是安全风险操作，请确认你理解风险
    sed -i 's/^\(root:\)[^:]*:/\1:/' "$SHADOW"
    echo "Set root password field to empty in $SHADOW (passwordless root)."
    echo "WARNING: This allows login without password. Only use in trusted networks."
  else
    echo "Leaving $SHADOW unchanged. To clear root password set CLEAR_ROOT_PASS=1 in the environment."
  fi
else
  echo "Warning: $SHADOW not found, skipping root password modification"
fi

# 5) 针对 512MB 内存优化（提升文件句柄限制）
SYSCTL_DIR="package/base-files/files/etc"
mkdir -p "$SYSCTL_DIR"
SYSCTL_FILE="$SYSCTL_DIR/sysctl.conf"
backup_file "$SYSCTL_FILE"
# 仅在文件中不存在该项时追加，避免重复
grep -q "^fs.file-max=100000" "$SYSCTL_FILE" 2>/dev/null || echo "fs.file-max=100000" >> "$SYSCTL_FILE"
echo "Ensured fs.file-max=100000 in $SYSCTL_FILE"

echo "Customization script finished."
echo "Note: Check the .bak_* files for backups of modified files."
