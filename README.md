# GoodReader

一个**免费、开源、本地优先**的 Android 电子书阅读器，使用 Flutter 构建。

目标是复刻主流中文阅读器的完整体验（书架 / 阅读器 / 笔记 / 统计 / 听书 / AI / 云同步 / OCR），
以**独立实现**的方式逐阶段推进，不复制任何第三方应用的代码、素材或品牌。

> 本仓库代码为原创实现。APK 仅用于个人学习与自用，请勿用于侵犯他人版权的用途。

---

## 当前进度（v0.1）

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| 书架 | ✅ | 网格 / 列表 / 极简三视图，标签、收藏、私密书籍、排序、搜索 |
| 导入 | ✅ | TXT、EPUB；自动解析书名 / 作者 / 简介 / 封面 / 目录 |
| TXT 引擎 | ✅ | 智能分章（中文章节名正则），UTF-8 / UTF-16 / GBK 自动识别 |
| EPUB 引擎 | ✅ | 自研 ZIP + OPF 解析，spine 章节顺序，NCX / EPUB3 nav 目录标题 |
| 阅读器 | ✅ | 章节翻页、点击左右翻页、目录跳转、进度记忆、段落缩进 |
| 排版 | ✅ | 6 套阅读主题、字号 / 行距 / 字距 / 页边距 / 缩进 / 字体 |
| 笔记 | ✅ | 选中即高亮、写笔记、书签、笔记检索、导出到剪贴板 |
| 统计 | ✅ | 今日 / 累计时长字数、连续天数、7 日柱状图、12 周热力图、时长排行 |
| 听书 | ✅ | 系统 TTS，语速 / 音调 / 语言可调，自动连读下一章 |
| 设置 | ✅ | 主题模式与主题色、书架视图、阅读目标、数据清空 |

完整的功能拆解、已完成 / 待实现清单见 [`docs/FEATURE-MAP.md`](docs/FEATURE-MAP.md)。

---

## 构建

本仓库**不依赖本地 Android 环境**，APK 由 GitHub Actions 自动构建。

### 方式一：GitHub Actions（推荐）

推送到 `main` 或手动触发 `Android CI` workflow：

1. 进入仓库 **Actions** 页面 → 选择 `Android CI` → **Run workflow**。
2. 构建完成后在本次运行的 **Artifacts** 中下载 `goodreader-apk`。
3. 打 tag（如 `v0.1.0`）推送后，会自动创建 Release 并附带 APK：

```bash
git tag v0.1.0
git push origin v0.1.0
```

产物包含：

- `goodreader-<ref>-universal.apk`：全架构通用包，任何设备都能装
- `goodreader-<ref>-arm64-v8a.apk` 等：按 ABI 拆分的更小安装包

### 方式二：本地构建（可选）

需要自行安装 Flutter 3.24+ 与 Android SDK：

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

---

## 技术栈

- **Flutter 3.24** + Material 3，Riverpod 状态管理，go_router 路由
- **Hive** 本地存储（书籍 / 章节 / 笔记 / 阅读记录 / 设置）
- 自研 **TXT / EPUB 解析引擎**（`archive` + `xml` + `html`，无第三方电子书依赖）
- 自研 **TTS 平台通道**（原生 Android `TextToSpeech` + `MethodChannel`，不依赖第三方插件）
- `file_picker` 导入、`fl_chart` 统计图表

## 目录结构

```
lib/
├── core/            # 主题、路由
├── data/            # 模型、Hive 存储、仓储层
├── features/        # 书架 / 阅读器 / 笔记 / 统计 / 设置 / 书籍详情
│   └── reader/engines/   # TXT / EPUB 解析引擎
├── services/        # 导入服务、TTS 服务
└── state/           # Riverpod providers 与控制器
```

## 许可证

[MIT](LICENSE)
