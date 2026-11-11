# 分支与上游同步

本仓库是 [91917878qq/miaomiao-assistant](https://github.com/91917878qq/miaomiao-assistant) 的 fork。产品方向、工程结构和上游版本以原作者仓库为准；fork 只维护兼容性、构建和发布体验上的最小改进。

## 长期分支

- `main`：与 `upstream/main` 对齐的唯一长期分支，必须保持可构建。
- 不设长期 `develop` 分支。
- 旧的 apktool/smali 主线已归档到标签 `archive/apktool-main-2026-11-11`，不移动、不删除。

## 短分支

从 `main` 创建，完成后通过 Pull Request 回到 `main`：

- `feat/<topic>`：功能；
- `fix/<topic>`：缺陷修复；
- `docs/<topic>`：文档；
- `test/<topic>`：测试和验证；
- `chore/<topic>`：CI、构建和仓库维护；
- `upstream/<topic>`：准备提交给上游的修复，必须从 `upstream/main` 创建，上游 PR 合并后删除。

合并方式使用 squash merge，合并后自动删除 head 分支。

## 上游同步

- 上游新增提交时，先核对 `upstream/main`，再让 fork 的 `main` 快进或合并；不重写上游历史。
- fork 自己的改动只放在短分支中，不同步到上游的改动不混入上游 PR。
- 已发布 tag、归档 tag 和 Release 资产不移动、不覆盖。

## PR 门禁

- GitHub Actions 的 `build` 检查必须通过；
- 本地至少运行 `./gradlew :app:assembleDebug`；
- 用户可见改动同步更新 `CHANGELOG.md`；
- PR 中不得包含 keystore、密码、`local.properties`、构建产物或真实个人路径。

## 清理规则

- 合并后的短分支自动删除；
- 未合并分支超过 30 天，先确认是否仍需要，再决定关闭或删除；
- 不强制推送 `main`，不删除已发布 tag。
