# 更新记录

## 3.0.1 - 2026-11-09

- 修复无障碍服务「设置」入口仍指向旧包名 `com.ronie.miao.MainActivity` 的问题，现使用 `com.miaomiao.assistant.MainActivity`。
- 移除未使用的 `INTERNET`、`RECEIVE_BOOT_COMPLETED` 权限，并关闭应用数据备份（`allowBackup=false`）。
- 版本提升至 3.0.1（versionCode 52）。
- 将 2.5.0 历史安装包归档到 `legacy/喵喵助手2.5.0.apk`，并补充 SHA-256 与用途说明。
- 继续使用 `miao_config` SharedPreferences 和原有设置键；使用原发布证书签名且 versionCode 递增时，覆盖安装会保留规则、预设、无障碍与悬浮窗设置。
- 增加 Windows/WSL 一键构建脚本，固定 apktool 2.10.0 并在 Windows 侧校验 SHA-256。
- 增加 Linux/WSL 构建脚本和 GitHub Actions 自动回编译工作流。
- 构建脚本支持默认调试证书签名、自定义发布证书签名、`zipalign` 和签名校验。
- 新增 `scripts/check-upgrade.ps1`，核对包名、`versionCode` 严格递增和签名证书 SHA-256；不匹配时退出码为 1。
- `scripts/build-wsl.ps1` 新增 `-LegacyApk` 和 `-BuildTools`；签名后自动执行升级兼容门禁，不通过则构建失败。
- 发布证书的 alias、store/key 密码支持通过 `MIAOMIAO_KEY_ALIAS`、`MIAOMIAO_STORE_PASS`、`MIAOMIAO_KEY_PASS` 环境变量传入，避免写入命令历史或仓库。
- 确认 2.5.0 与 3.0.1 共用 `miao_config`，设置键一致，启动流程没有清空或删除 SharedPreferences；同签名覆盖安装会保留设置。
- 验证负向路径：2.5.0 对默认 Debug 3.0.0 返回 `UPGRADE_COMPATIBLE=false`；临时同签名样本返回 `true`。
- 修复 `.gitignore` 的 UTF-8 编码损坏，补充构建产物、密钥和本地配置的忽略规则。
- 增加 `.gitattributes`，避免 APK、so、图片等二进制文件被 Git 当作文本处理。
- 标注旧版 2.5.0 与默认调试签名的证书差异；无卸载覆盖升级必须使用原发布 keystore。
- 在 Linux 文件系统中实测回编译 3.0.1，APK 通过 v2/v3 签名校验和 `zipalign -c -v 4`。
