# 喵喵助手（MiaoAssistant）

一款基于 Android 无障碍服务的文本自动改写辅助工具：在微信 / QQ 等聊天应用中，按规则自动替换文本、追加标点触发内容与颜文字，支持 QQ 猫爪包裹，并提供悬浮窗手动处理面板。

- 作者：91917878qq
- 反馈邮箱：1490964435@qq.com
- 最新版本：3.0.0（versionCode 51）
- 包名：com.miaomiao.assistant

## 功能

- 无障碍文本改写：实时规则替换（支持括号保护、随机替换）、标点触发追加、颜文字定时轮换、QQ 猫爪包裹
- 悬浮窗：可拖拽、贴边吸附，大小与不透明度实时生效，手动处理面板全程离线
- 规则系统：行内编辑「原文本 → 替换为」，保存 / 删除 / 导入 / 导出规则，最多 30 套预设
- 规则分享码：离线生成与导入（`MR1:` 开头的分享码）
- 功能体检：一键检测无障碍服务 / 悬浮窗权限 / 已选应用 / 版本信息
- 崩溃日志：本地记录，可导出日志包反馈
- 液态玻璃底部导航与玻璃模糊效果（模糊等级 0–2 可调）

## 构建

> 根目录的 `喵喵助手2.5.0.apk` 是历史版本；当前源码是 3.0.0（versionCode 51）。请用下面的方式生成 3.0.0 APK。

> 旧版 2.5.0 使用 `CN=MiaoMiao Assistant` 发布证书。Android 只允许同签名覆盖安装；默认 Debug 包仅用于开发验证，不能作为 2.5.0 的升级包。要实现无卸载升级，必须通过 `-Keystore` 使用原发布证书签名，并运行升级兼容检查。

本仓库是 apktool 解码工程（smali + 资源）。仓库中有 1421 组仅大小写不同的 smali 路径，Windows 的 NTFS 无法同时表示；因此 **Windows 用户必须通过 WSL/Linux 文件系统构建**，不要直接在 `D:\` 工作区运行 apktool。

### Windows（推荐）

要求：WSL2、Java 17+、Android SDK Build-Tools（包含 `zipalign.exe` 和 `apksigner.bat`）。

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-wsl.ps1
```

脚本会自动下载固定版本 apktool 2.10.0，在 WSL 的 Linux 文件系统中构建，然后使用本机 Android 调试证书签名。默认 Debug 证书仅用于开发验证。产物：

```text
dist\miaomiao-assistant-3.0.0-debug.apk
```

脚本会从当前 Git 的 `HEAD` 干净检出后构建；尚未提交的改动不会进入 APK。

如果已经手动下载了 apktool，可通过 `-ApktoolJar` 指定本地 jar，避免重复下载：

```powershell
.\scripts\build-wsl.ps1 -ApktoolJar D:\tools\apktool_2.10.0.jar
```

如果要使用自己的发布证书：

```powershell
.\scripts\build-wsl.ps1 -Keystore D:\secure\release.jks `
  -KeyAlias <alias> -StorePass <store-pass> -KeyPass <key-pass>
```

也可以把 alias 和密码放在本机环境变量里，避免出现在命令历史中：

```powershell
$env:MIAOMIAO_KEY_ALIAS = '<alias>'
$env:MIAOMIAO_STORE_PASS = '<store-pass>'
$env:MIAOMIAO_KEY_PASS = '<key-pass>'
.\scripts\build-wsl.ps1 -Keystore D:\secure\miao-release.jks
```

产物后缀为 `-release.apk`。不要把 keystore 或密码提交到仓库。也可以通过 `-Distro Ubuntu` 指定 WSL 发行版。

### 无卸载升级与设置保留

2.5.0 和 3.0.0 使用同一个 SharedPreferences 文件 `miao_config`，设置键名一致；启动流程没有调用 `clear()`、`deleteSharedPreferences()` 或写回默认值来重置配置。因此，只要签名证书相同，覆盖安装会保留：

- 规则、预设和分享码相关设置
- 无障碍服务开关与已选应用
- 悬浮窗位置、大小、不透明度
- 其他 `miao_config` 数据和应用私有文件

构建升级包时，建议同时提供旧 APK，让脚本在签名后自动执行门禁：

```powershell
.\scripts\build-wsl.ps1 -Keystore D:\secure\miao-release.jks `
  -KeyAlias <alias> -StorePass <store-pass> -KeyPass <key-pass> `
  -LegacyApk .\喵喵助手2.5.0.apk
```

也可以单独检查已生成的 APK：

```powershell
.\scripts\check-upgrade.ps1 `
  -OldApk .\喵喵助手2.5.0.apk `
  -NewApk .\dist\miaomiao-assistant-3.0.0-release.apk
```

只有输出 `UPGRADE_COMPATIBLE=true` 才能作为覆盖升级包发布。检查会同时核对包名、`versionCode` 严格递增和签名证书 SHA-256：

- 2.5.0 签名证书：`31b4fdeda7978308fa185d9df78f52e9789c2d085feab2ae188db3d04f89369c`
- 默认 Debug 证书：`865d3872a44e1500a1ee6fdf28e5aa3780763670d20029b91b0298b3ce9ff627`

因此当前默认 Debug 包检查结果必定是 `UPGRADE_COMPATIBLE=false`，这是预期行为。

> 如果没有原发布 keystore，Android 无法完成同包名覆盖升级。这是系统签名校验，不是构建脚本可以绕过的限制。可选方案只有：找回原 keystore；卸载后重装并重新配置；或改用新包名并行安装（不会继承旧版数据）。旧版支持规则导入/导出，至少可以先导出规则，卸载安装后再导入；无障碍和悬浮窗权限仍需重新授权。

### Linux / WSL

```bash
bash scripts/build.sh "$PWD" "$PWD/dist"
```

输出 `dist/miaomiao-assistant-<version>-unsigned.apk`。之后可使用 Android SDK build-tools 中的 `zipalign` 和 `apksigner` 完成对齐与签名。

如果环境中无法访问 GitHub，可先手动下载 apktool 2.10.0，再通过 `APKTOOL_JAR=/path/to/apktool_2.10.0.jar bash scripts/build.sh ...` 指定本地 jar。

### 手动构建

```bash
# 回编译
apktool b MiaoMiaoAssistant -o app-unsigned.apk

# 对齐 + 签名（需要 release keystore）
zipalign -p -f 4 app-unsigned.apk app-aligned.apk
apksigner sign --ks <your-release.keystore> \
  --ks-key-alias <alias> \
  --ks-pass pass:<store-pass> \
  --key-pass pass:<key-pass> \
  --out app-release.apk app-aligned.apk
```

> `dist/`、`build/`、APK、keystore 和本地 SDK 配置均已在 `.gitignore` 中排除。

## 许可

本软件仅用于个人学习与文本输入辅助。请遵守所在地区法律法规，勿用于任何违法违规用途。
