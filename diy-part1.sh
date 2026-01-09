#!/bin/bash
# 修改 feeds.conf.default，添加插件源
echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages' >> feeds.conf.default
echo 'src-git small https://github.com/kenzok8/small-package' >> feeds.conf.default
