#!/usr/bin/env bash
# Prune .config to a minimal set suitable for 32MB devices (phicomm_k2p)
# Usage: ./scripts/prune_config.sh /path/to/openwrt
set -euo pipefail

WORKDIR="${1:-.}"
CONFIG="${WORKDIR}/.config"

if [ ! -d "$WORKDIR" ]; then
  echo "Error: workdir $WORKDIR not found"
  exit 1
fi

if [ ! -f "$CONFIG" ]; then
  echo "No .config found at $CONFIG; creating a minimal .config using defconfig"
  (cd "$WORKDIR" && make defconfig)
fi

# Backup
cp -a "$CONFIG" "${CONFIG}.bak.$(date +%s)"
echo "Backup .config -> ${CONFIG}.bak.*"

# List of large/problematic packages to remove (exact keys)
UNSET_KEYS=(
CONFIG_PACKAGE_luci-app-openclash
CONFIG_PACKAGE_luci-i18n-openclash-zh-cn
CONFIG_PACKAGE_luci-app-netdata
CONFIG_PACKAGE_luci-i18n-netdata-zh-cn
CONFIG_PACKAGE_luci-theme-argon
CONFIG_PACKAGE_luci-app-argon-config
CONFIG_PACKAGE_luci-i18n-argon-config-zh-cn
CONFIG_PACKAGE_luci-app-adbyby-plus
CONFIG_PACKAGE_luci-i18n-adbyby-plus-zh-cn
CONFIG_PACKAGE_luci-app-turboacc
CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn
)

for key in "${UNSET_KEYS[@]}"; do
  sed -i "/^${key}=/d" "$CONFIG" || true
  sed -i "/^# ${key} is not set/d" "$CONFIG" || true
done

# Ensure minimal keep list (set to =y)
KEEP_KEYS=(
CONFIG_TARGET_ramips
CONFIG_TARGET_ramips_mt7621
CONFIG_TARGET_ramips_mt7621_DEVICE_phicomm_k2p

CONFIG_LUCI_LANG_zh_Hans

CONFIG_PACKAGE_luci
CONFIG_PACKAGE_luci-i18n-base-zh-cn
CONFIG_PACKAGE_luci-app-ttyd
CONFIG_PACKAGE_dropbear
CONFIG_PACKAGE_kmod-tun
CONFIG_PACKAGE_luci-app-nlbwmon
CONFIG_PACKAGE_kmod-zram
)

# Remove any existing mentions and add as KEY=y at the end
for key in "${KEEP_KEYS[@]}"; do
  sed -i "/^${key}=/d" "$CONFIG" || true
  sed -i "/^# ${key} is not set/d" "$CONFIG" || true
  echo "${key}=y" >> "$CONFIG"
done

# Sync .config with defconfig (requires make in WORKDIR)
echo "Running make defconfig to sync configuration (this may modify .config)"
( cd "$WORKDIR" && make defconfig )

echo "Prune complete. Original .config backed up. New .config prepared at $CONFIG"
```


````bash name=scripts/add_kenzo_feeds.sh url=https://github.com/shuixiekongao/K2P-32M-512M/blob/main/scripts/add_kenzo_feeds.sh
#!/usr/bin/env bash
# Add kenzo feeds to feeds.conf.default (idempotent, with backups)
#
# Usage:
#   ./scripts/add_kenzo_feeds.sh              # will try current dir then openwrt/
#   OPENWRT_DIR=path/to/openwrt ./scripts/add_kenzo_feeds.sh

set -euo pipefail

# Third-party feed lines to add
FEEDS_TO_ADD=(
  "src-git kenzo https://github.com/kenzok8/openwrt-packages"
  "src-git small https://github.com/kenzok8/small-package"
)

# Locate feeds.conf.default (prefer explicit env var OPENWRT_DIR, then current, then openwrt/)
FEEDS_FILE="${OPENWRT_DIR:-}/feeds.conf.default"
if [ -z "${OPENWRT_DIR:-}" ]; then
  if [ -f "./feeds.conf.default" ]; then
    FEEDS_FILE="./feeds.conf.default"
  elif [ -f "./openwrt/feeds.conf.default" ]; then
    FEEDS_FILE="./openwrt/feeds.conf.default"
  else
    echo "Error: feeds.conf.default not found in current directory or ./openwrt/"
    exit 1
  fi
fi

# Normalize path
FEEDS_FILE="$(realpath "$FEEDS_FILE")"
echo "Using feeds file: $FEEDS_FILE"

# Backup
BACKUP="${FEEDS_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$FEEDS_FILE" "$BACKUP"
echo "Backup created: $BACKUP"

# Append if not present
for line in "${FEEDS_TO_ADD[@]}"; do
  # Use fixed-string exact match to avoid duplicates
  if grep -Fxq "$line" "$FEEDS_FILE"; then
    echo "Already present, skipping: $line"
  else
    echo "$line" >> "$FEEDS_FILE"
    echo "Appended: $line"
  fi
done

echo "Done. To refresh and install feeds run (inside the openwrt tree):"
echo "  ./scripts/feeds update -a"
echo "  ./scripts/feeds install -a"
```

Next steps — 提交 & 运行（最简单）
1. 在你的本地仓库复制上面文件到对应路径并 commit：
   - .github/workflows/openwrt-builder.yml
   - scripts/prune_config.sh
   - scripts/add_kenzo_feeds.sh (如果需要 kenzo feeds)
2. git add, commit, push:
   - git add .github/workflows/openwrt-builder.yml scripts/prune_config.sh scripts/add_kenzo_feeds.sh
   - git commit -m "Add K2P minimal OpenWrt build workflow and prune scripts"
   - git push
3. 到 GitHub 仓库页面 → Actions → 运行 “OpenWrt Builder (K2P minimal-ready)”（Run workflow），保持默认参数或根据需要修改 profile/packges。
4. 等 workflow 完成后下载 artifact OpenWrt_firmware...，在本地查看：
   - ls -lh openwrt/bin/targets/*/*
   - 把 sysupgrade.bin 的大小和文件名发给我，或把 build.log 的最后 200 行贴来。

我会在你把 artifact 输出（或固件大小）贴上来后：
- 精确判断是否能刷入 32MB（大多数 32MB 设备可用空间约 28.x MB）；
- 如果仍然太大，我会按包大小给出逐项移除建议，并把 prune 列表进一步精简到可刷入的最终 PACKAGES 字符串，或建议改用更极小的内置（例如无 LuCI，仅 dropbear + ttyd）并提供相应 .config/PACKAGES。

需要我把 customize_openwrt.sh（修改默认 IP/主机名/语言/文件句柄）也一并加入并自动执行在 workflow pre-step 吗？如果需要回复 “加 customize”，我会把文件内容和 workflow wiring 发给你。
