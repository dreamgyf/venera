# iPhone Duo 适配与验证

## 构建

发布 iPhone Duo 版本请使用 **Xcode 27.1 / iOS 27.1 SDK 或更新版本**，以及
`pubspec.yaml` 指定的 Flutter 版本。旧 SDK 构建的安装包即使运行在新系统上，也可能
处于带留白的兼容显示模式。本项目的最低支持版本为 iOS 15，符合 Xcode 27 的部署目标要求；
无需把最低支持的 iOS 版本提升到 27.1。

```sh
export DEVELOPER_DIR=/Applications/Xcode_27.1.app/Contents/Developer
flutter pub get
flutter test
flutter build ios --release --no-codesign
```

无签名构建用于检查编译；安装到真机仍需常规 iOS 签名。`Build ALL` 的 iOS 任务和
`Validate iOS` 工作流均选择 Xcode 27.1。

## 行为

- 使用 Flutter 的 UIScene 生命周期启动，文件选择器在当前活动场景中展示。
- 导航根据实际可用宽度切换底栏/侧栏，横竖屏都避开左右安全区域；较矮窗口的侧栏可滚动。
- 折叠、展开、旋转时保留导航栈和页面状态。
- 阅读器按现有“竖屏每页图片数 / 横屏每页图片数”设置重新排版；例如设为 1 / 2，
  在窗口从竖向变为横向时切换单双页。连续阅读模式保持每项一张图片。
- 重新排版以图片序号保存阅读位置。例如第 10 张图片展开后处于 9–10 双页，收起后仍为
  第 10 张；首页单图和章节末尾评论页也参与位置换算。
- 图片加载界面独立处理尺寸和主题变化，避免折叠时已加载图片被 PhotoView 错误重置为持续转圈。
- 页码、时钟、电量和章节按钮尊重安全区域。
- iOS 27.1 的 reserved regions 通过原生桥接写入 Flutter `MediaQuery.displayFeatures`，
  使支持该机制的 Flutter 弹窗能避开横贯窗口的折叠区域。窗口尺寸不匹配的旧事件会被忽略，
  引擎已有的 display features 会保留。

原生桥接按运行时版本判断 API 是否可用。旧编译器可构建不含区域查询的回退分支，用于
兼容性检查；**Xcode 27.0 不是受支持的 Duo 构建工具链**，请直接使用 27.1 或更新版本。
自绘阅读工具栏和漫画网格仍使用原有布局，不会自动获得 UIKit 的竖向工具栏或全部姿态布局。

## 发布前检查

2026-11-27 已使用 Xcode 27.2 打开 `ios/Runner.xcworkspace`，在 iOS 27.2 的
iPhone Duo 模拟器中编译并运行。使用 8 页本地测试漫画验证了以下连续操作：

- 收起时显示第 5 页，展开后显示第 5–6 页，再次收起仍显示第 5 页。
- 半展开后显示第 5–6 页，旋转到竖向后显示第 5 页；各状态下图片均正常渲染，无持续加载动画。

全部 28 项自动测试通过，包括加载完成后反复改变尺寸和主题的图片显示回归测试，
以及未设置追更收藏夹时打开漫画的回归测试。1.6.4（164）已再次通过模拟器启动与双页切换检查；
同一本地漫画同时出现在历史和本地列表时，封面动画和图片路径也已修正。
上述结果仅包含模拟器与自动测试，尚未进行 Duo 真机验证。

下表是完整发布回归清单，仍需按场景在 Xcode Device Hub 的 iPhone Duo 模拟器及真机上
检查；单元测试与组件测试不能替代 UIKit 区域事件、系统文件选择器和真实显示切换的验证。

| 场景 | 检查点 |
| --- | --- |
| 外屏冷启动、前后台切换 | 正常启动，安全区域正确，无兼容模式留白 |
| 外屏 → 内屏 → 外屏 | 当前标签、漫画详情、搜索输入和滚动位置不丢失 |
| 阅读中展开/收起 | 左右翻页、右至左阅读、连续阅读均保持阅读位置 |
| 每页 1 / 2 / 3 张图片 | 开启/关闭首页单图，反复切换尺寸；历史记录正确 |
| 翻页动画期间折叠 | 旧动画结束时不会覆盖新位置 |
| 章节末尾评论页 | 改变尺寸后仍停留评论页；关闭评论设置后回到最后图片 |
| 半折、旋转、左右分屏 | 弹窗避开有效分隔区域；导航和操作按钮可访问 |
| 键盘、较大字体、短窗口 | 无溢出，侧栏设置入口可滚动到达 |
| 选择/取消目录、导入漫画 | 文件选择器在活动场景展示且回调结束 |
| 普通 iPhone / iPad / Android | 页面导航、阅读和文件导入无回归 |

## 官方资料

- [Apple：Three steps to make your app shine on iPhone Duo](https://developer.apple.com/iphone-duo/prepare/)
- [Apple：Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
- [Flutter：UIScene adoption](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)
- [UIKit：reservedRegions(kind:options:)](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:))
