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
| 书架陈列 | ✅ | 封面书脊光影、每行立体书架、仅封面、按宽度自动列数（或固定 3–6 列） |
| 底栏 | ✅ | 项目与顺序可配、图标可选文字、固定磨砂 / 悬浮玻璃、高度可调、独立深浅色 |
| 主题配色 | ✅ | 10 套（色值取自目标应用主题预览图的实测主色），带名字可选 |
| 导入 | ✅ | TXT、EPUB；自动解析书名 / 作者 / 简介 / 封面 / 目录 |
| TXT 引擎 | ✅ | 智能分章（中文章节名正则），UTF-8 / UTF-16 / GBK 自动识别 |
| EPUB 引擎 | ✅ | 自研 ZIP + OPF 解析，spine 章节顺序，NCX / EPUB3 nav 目录标题 |
| 阅读器 | ✅ | 章节翻页、点击左中右翻页、目录跳转、进度记忆、全文搜索、读完页 |
| 翻页动画 | ✅ | 平移 / 覆盖 / 仿真折页 / 淡入 / 无动画 |
| 阅读模式 | ✅ | 翻页阅读 或 上下滚动（章节底部自动续读） |
| 手势 | ✅ | 左侧上下滑调亮度、右侧上下滑调音量、双指缩放（放大后可拖动） |
| 排版 | ✅ | 10 套阅读主题、字号/行距/字距/页边距/段首缩进/段间距、对齐、字体 |
| 页眉页脚 | ✅ | 8 个宏（书名/章节/卷名/本章进度/全书进度/页码/时间/电量），可点击插入 |
| 中文排版细节 | ✅ | 首字下沉、版框（细线 / 外细内粗）、划线颜色 6 色 |
| 简繁转换 | ✅ | 不转换 / 转简体 / 转繁体（通用 · 台湾正体 · 香港繁体），等长映射不错位 |
| 墨水屏模式 | ✅ | 关闭翻页动画与界面投影，开关即时生效 |
| 笔记 | ✅ | 选中即划线（可配色）、写笔记、书签、笔记检索、导出到剪贴板 |
| 统计 | ✅ | 今日 / 累计时长字数、连续天数、7 日柱状图、12 周热力图、时长排行 |
| 听书 | ✅ | 原生 TTS，语速 / 音调 / 语言可调，自动连读下一章 |
| 检查更新 | ✅ | 读取 GitHub Releases、比较版本、下载 APK、交给系统安装器 |
| 边框图库 | ✅ | 导入边框花纹图、九宫格切割设计、实时预览（绿线定拉伸区、橙框定安全区） |
| 分享海报 | ✅ | 摘录卡 / 书籍卡，4 套实测配色、3 种比例、可套边框，导出 1080 宽并调系统分享 |
| 服务 | ✅ | 五种能力共用一个「自带端点」骨架：AI / 同步 / 识别 / 听书 / 书源；密钥单独存放 |
| 阅读助手 | ✅ | OpenAI 兼容多轮对话，按书保存历史，30+ 家供应商预设 |
| 云同步 | ✅ | WebDAV 与 S3（SigV4），一本书一份文档，冲突按较新一侧合并 |
| Wi-Fi 传书 | ✅ | 本机起 HTTP 服务，浏览器上传，六位连接码，上传即入库 |
| 书源 | ✅ | 声明式规则（CSS + 正则），搜到的书直接进书架，正文按章懒加载 |
| 图片转文字 | ✅ | 交给自配识别服务，结果可编辑并存成一本书 |

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
- 自研 **原生通道**：`goodreader/tts`（TextToSpeech）与 `goodreader/native`（亮度 / 音量 / 常亮 / 电量 / 安装 APK / 打开链接），不依赖任何第三方插件
- 自研 **排版变换层**（`lib/features/reader/text_layout.dart`）：段首缩进与段间距以单调变换实现，划线/书签/搜索偏移可精确双向映射
- 自研 **简繁转换**（`lib/features/reader/convert/`）：Unicode Unihan 单字表 + OpenCC 词组表，**全部映射等长**，因此切换简繁不会让划线错位
- 自研 **九宫格切割模型**（`lib/data/models/stretch_border.dart`）：边框花纹图按四角 / 四边 / 中心切分，四个角永远不被拉伸；原图比例、可拉伸矩形、安全框分属三个独立概念，页面缩放时互不推导
- 自研 **文件头解析**（`lib/data/services/image_header.dart`）：不解码像素读出 PNG / JPEG / WebP 的宽高，避开这一版 Flutter 没有失败回调的图片解码器
- 自研 **海报渲染**（`lib/features/share/poster/`）：按 360 逻辑宽排版一次，导出时 3 倍抓图得到 1080 宽——预览与成品是同一套布局，不是两套
- 自研 **底栏配置模型**（`lib/data/models/bottom_bar.dart`）：顺序里永远含全部槽位、另存一份隐藏集，关掉的项不会丢位置；全关时退回只显示书架
- 自研 **书架陈列模型**（`lib/data/models/shelf_appearance.dart`）：网格宽高比与格子排版用同一组常量算出，行高写死，避免溢出
- 自研 **书源引擎**（`lib/services/booksource/`）：规则串 `选择器[@属性][##正则##替换]`，**不执行脚本**——书源是第三方配置，能执行代码的书源等于把设备交出去
- 自研 **SigV4 签名**（`lib/services/sync/s3_backend.dart`）：用 AWS 官方的 `get-vanilla` 向量逐字节校验后才用
- 自研 **同步编排**（`lib/services/sync/`）：只认识文档，不认识 WebDAV 还是 S3；`apply` 返回布尔，落不了地的不算下载
- `file_picker` 导入、`fl_chart` 统计图表、`dart:io` HttpClient 检查更新

## 目录结构

```
lib/
├── core/            # 主题、路由
├── data/            # 模型、Hive 存储、仓储层
├── features/        # 书架 / 阅读器 / 笔记 / 统计 / 设置 / 书籍详情 / 分享
│   ├── reader/engines/   # TXT / EPUB 解析引擎
│   └── share/            # 边框图库与九宫格切割设计器
├── services/        # 导入服务、TTS、原生能力、更新检查
└── state/           # Riverpod providers 与控制器
```

## 第三方数据

`assets/convert/` 下的简繁转换表由 `scripts/generate_convert_tables.py` 生成，来源：

- **OpenCC**（Apache-2.0）`STCharacters` / `TSCharacters`（单字）、`STPhrases` / `TSPhrases`（词组）、`TWVariants` / `HKVariants`（地区字形）
- Unicode **Unihan** `Unihan_Variants.txt`，仅用于补充 OpenCC 未收录的字

所有映射都保证 **UTF-16 长度不变**（生成时强制过滤），所以切换简繁不会让划线、书签、搜索偏移错位；`test/chinese_convert_test.dart` 会在 CI 里校验这一不变量。

运行 `python scripts/generate_convert_tables.py --workdir <含源文件的目录>` 可重新生成。

## 许可证

[MIT](LICENSE)
