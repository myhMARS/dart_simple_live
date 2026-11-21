# simple_live_app

基于核心库实现的Flutter APP客户端。

## TODO

- [ ] 支持桌面平台
- [ ] iOS播放问题
- [ ] 全屏、非全屏弹幕样式分离
- [ ] 重写直播间

## 版本与更新检查

- 每次修改功能或修复后，必须递增 `pubspec.yaml` 的版本号（如 `1.11.5+11105`）。
- 同步更新仓库根目录 `assets/app_version.json` 的 `version`、`version_num` 和 `version_desc`，其中 `version_num` 必须等于 pubspec 的 `+build` 数字。
- App 启动时会静默检查 `myhMARS/dart_simple_live` 的 `assets/app_version.json`；也可以在「我的 → 检查更新」手动检查。
- CI 会校验 pubspec 与 `assets/app_version.json` 的版本是否一致，不一致会直接构建失败。
