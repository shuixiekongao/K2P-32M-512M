
#!/bin/bash

# 1. 修改默认 IP 为 192.168.2.1 (避免与光猫 192.168.1.1 冲突)
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# 2. 修改默认主机名为 K2P-Pro
sed -i 's/OpenWrt/K2P-Pro/g' package/base-files/files/bin/config_generate

# 3. 强制默认语言为中文
sed -i 's/os.set_i18n("auto")/os.set_i18n("zh-cn")/g' package/feeds/luci/luci-base/luasrc/view/themes/argon/header.htm || true

# 4. 移除默认密码 (改为无密码，首次登录直接点击“登录”)
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:99999:7:::/g' package/base-files/files/etc/shadow

# 5. 针对 512MB 内存优化（提升内核文件句柄限制，利于科学上网）
echo "fs.file-max=100000" >> package/base-files/files/etc/sysctl.conf
