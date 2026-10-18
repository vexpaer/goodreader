# GoodReader 功能蓝图（Feature Map）

本文档是**功能范围的事实来源**。左侧"来源"一列标注了每项能力在逆向分析中的证据，
右侧"状态"标注 GoodReader 的实现进度。

> 分析方法：解包目标 APK（Flutter 应用），读取 `AndroidManifest.xml`、
> `assets/flutter_assets/` 资源清单、`FontManifest.json`、`NativeAssetsManifest.json`、
> 内置 `changelog/latest.json` 与功能说明文本，并比对 `lib/*.so` 原生库构成。
> 仅提取**功能范围**，未复制任何代码、素材或品牌。

## 0. 目标应用技术构成（逆向结论）

| 项 | 结论 | 证据 |
| --- | --- | --- |
| 框架 | Flutter（Dart AOT） | `lib/*/libflutter.so`、`libapp.so` |
| 数据库 | SQLCipher 加密 SQLite | `libsqlcipher.so` |
| PDF | PDFium | `libpdfium.so`、`NativeAssetsManifest.json` |
| 音视频 | mpv (media_kit) | `libmpv.so`、`packages/media_kit/` |
| 推理 | ONNX Runtime | `libonnxruntime.so` |
| OCR | Google MLKit 中文文字识别 | `libmlkit_google_ocr_pipeline.so`、`play-services-mlkit-text-recognition-chinese` |
| 脚本 | QuickJS | `libfastdev_quickjs_runtime.so`、`packages/flutter_js/` |
| 压缩 | 7zip / unrar | `libflutter_7zip.so`、`libunrar.so` |
| UI 组件 | shadcn_flutter、liquid_glass_renderer | `packages/shadcn_flutter/`、`packages/liquid_glass_renderer/` |
| 数学排版 | flutter_math_fork (KaTeX) | `packages/flutter_math_fork/` |
| 国际化 | 国家/地区旗帜包 | `packages/country_flags/res/si/*.si` |
| 商业化 | Google Play Billing、Firebase、支付宝/微信图标 | `billing.properties`、`firebase-*`、`assets/images/alipay.png`、`wechat.png` |

## 1. 书架

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 网格 / 列表 / 极简列表三种视图 | changelog、功能说明 | ✅ 已实现 |
| 封面填充模式（裁剪 / 完整） | changelog「封面填充模式新增完整」 | ⬜ 待实现 |
| 标签、多级标签、标签筛选 | 功能说明 2.1 | ✅ 基础标签；多级 ⬜ |
| 书单（集合）与批量加入书单 | changelog「书单里的书可以一次加入多个其他书单」 | ⬜ 待实现 |
| 系列 / 卷号，读完自动读下一卷 | changelog「支持书籍系列和卷号」 | ⬜ 待实现 |
| 作者评分、国家地区、译名、批量修改 | changelog | ⬜ 待实现 |
| 分类分组、仅筛选时显示、快速筛选 | changelog | ⬜ 待实现 |
| 自定义拖拽排序、多选拖动、建分组 | changelog | ⬜ 待实现 |
| 全库正文搜索 | changelog「支持全库书籍正文搜索」 | ⬜ 待实现 |
| 顶栏磨砂 / 渐进模糊 | changelog、`bookshelf_progressive_blur.frag` | ⬜ 待实现 |
| Wi-Fi 局域网传书 | 功能说明 2.1 | ⬜ 待实现 |
| 私密书籍 + 生物识别解锁 | 功能说明 7、`libsqlcipher.so` | 🟡 已可标记私密；生物识别 ⬜ |

## 2. 书籍格式

| 格式 | 来源 | 状态 |
| --- | --- | --- |
| TXT | 功能说明 2.2 | ✅ 已实现（含 GBK/UTF-16 识别、智能分章） |
| EPUB | 功能说明 2.2 | ✅ 已实现（元数据、封面、spine 目录） |
| PDF | `libpdfium.so` | ⬜ 待实现 |
| MOBI / AZW / AZW3 | 功能说明 2.2 | ⬜ 待实现 |
| CBZ / CBR 漫画 | `libunrar.so`、`libflutter_7zip.so` | ⬜ 待实现 |

## 3. 阅读器

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 章节翻页、目录跳转、进度记忆 | 功能说明 11 | ✅ 已实现 |
| 点击左中右翻页 / 呼出菜单 | 功能说明 11 | ✅ 已实现（左 28% 上一页、右 28% 下一页、中间呼出菜单） |
| 翻页动画：平移 / 覆盖 / 仿真折页 / 淡入 / 无动画 | `reader_page_view_simulation.frag`、`reader_page_view_book_flip.frag` | ✅ 已实现（仿真为透视折页，非逐像素卷曲） |
| 掌阅墨水屏水波纹翻页 | changelog「掌阅墨水屏自带的水波纹翻页动画」 | ⬜ 待实现 |
| 上下滚动阅读 | changelog | ✅ 已实现（章节内连续滚动，读到章节底部自动进入下一章） |
| 自动翻页（5/10/20/30/60 秒） | 功能说明 11.4 | ✅ 已实现 |
| 左侧上下滑动调亮度 | 主流阅读器通用交互 | ✅ 已实现（含 HUD 指示器） |
| 右侧上下滑动调音量 | 主流阅读器通用交互 | ✅ 已实现（含 HUD 指示器） |
| 阅读时保持屏幕常亮 | — | ✅ 已实现 |
| 双指缩放（放大后可单指拖动） | changelog「所有页面都能双指放大」 | ✅ 已实现 |
| 翻页音效 / 翻页振动 | `assets/audio/page_turn/*.wav` | ✅ 已实现（系统音效 + 触感，无额外音频资源） |
| 墨水屏模式 | changelog「优化墨水屏模式，开关即时生效」 | ✅ 已实现（关闭动画与投影） |
| 竖排阅读、从右往左 | changelog | 🟡 设置项已留；渲染 ⬜ |
| 简繁转换（通用繁体 / 台湾正体 / 香港繁体） | changelog「支持简体转繁体时选择台湾正体或香港繁体字形」 | ✅ 已实现（Unihan + OpenCC 词组表，等长映射，划线不错位） |
| 页眉页脚自定义（8 个宏：书名/章节/卷名/本章进度/全书进度/页码/时间/电量） | changelog「页眉页脚支持显示卷名-章节名，自定义模板新增卷名宏」 | ✅ 已实现 |
| 页面信息块 / 页面装饰 | changelog「支持页面信息块」 | ⬜ 待实现 |
| 版框（无 / 细线 / 外细内粗） | changelog「版框新增外细内粗样式」 | ✅ 已实现 |
| 首字下沉 | changelog「修复首字下沉后从首字往后划选会跳过旁边第一排文字」 | ✅ 已实现 |
| 读完页（加标签 / 回到开头） | changelog「优化读完页，可以直接给书加标签」 | ✅ 已实现 |
| 全文搜索 + 搜索历史（可逐条删除 / 清空） | 功能说明 11.3、changelog「优化搜索历史」 | ✅ 已实现 |
| 书内链接跳转、跳转后返回原处 | changelog | ⬜ 待实现 |
| 弹注（脚注弹窗） | changelog「部分书籍标题上的弹注图标点不开」 | ⬜ 待实现 |
| 双页模式 | changelog「双页模式下章首页的划线点不开」 | ⬜ 待实现 |
| 离线词典、生词高亮 | changelog | ⬜ 待实现 |
| 替换规则（正文替换） | changelog「优化替换规则」 | ⬜ 待实现 |
| 漫画模式（整屏看图） | changelog | ⬜ 待实现 |
| PDF 裁边、方向锁定、自由旋转 | changelog | ⬜ 待实现 |

## 4. 排版与外观

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 字号 / 行距 / 字距 / 页边距 | 功能说明 11.1 | ✅ 已实现 |
| 段首缩进 / 段间距 / 两端对齐 | 中文排版惯例 | ✅ 已实现 |
| 字体选择与自定义字体导入 | 功能说明 11.1 | 🟡 内置字体族已实现；导入字体 ⬜ |
| 阅读主题（10 套：纸张 / 米色 / 羊皮卷 / 护眼绿 / 青苔绿 / 石墨灰 / 蓝灰 / 暖棕 / 夜间 / 纯黑） | `assets/images/background/*.jpg` 14 款 | 🟡 10 套纯色主题；图片背景 ⬜ |
| 划线颜色（6 色可选，可在设置里改默认色） | changelog「修复多种颜色的文字阴影互相串色」 | ✅ 已实现 |
| 应用主题变体（11 款配色） | `assets/icons/variant/preview/*` | ✅ 8 色主题色选择 |
| 封面填充（裁剪 / 完整 / 拉伸） | changelog「封面填充模式新增完整」 | ✅ 已实现 |
| 圆角、按钮样式全局设置 | 功能说明 6 | ⬜ 待实现 |
| 恢复已删除的预置主题 | changelog | ⬜ 待实现 |
| 图库 / 主题库管理 | changelog「阅读主题支持独立页管理」 | ⬜ 待实现 |

## 5. 笔记

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 划线 / 高亮（多色） | 功能说明 5.1 | ✅ 已实现（单色，多色待加） |
| 备注 | 功能说明 5.1 | ✅ 已实现 |
| 书签 | 功能说明 5 | ✅ 已实现 |
| 按时间 / 章节排序，升降序 | changelog | 🟡 默认按章节排序 |
| PDF 涂鸦（荧光笔、虚线、直线、箭头、矩形、椭圆）+ 备注标签 | changelog | ⬜ 待实现 |
| 笔记导出 TXT | 功能说明 5.2 | ✅ 已实现（剪贴板） |
| 笔记生成海报 | 功能说明 5.2、`assets/share/templates/note.html` | ⬜ 待实现 |

## 6. 阅读统计

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 总时长 / 字数 / 平均、进度概览 | 功能说明 3 | ✅ 已实现 |
| 阅读时间分布柱状图 | 功能说明 3 | ✅ 已实现（7 日） |
| 阅读时长书籍排行 | 功能说明 3 | ✅ 已实现 |
| 年度热力图 | 功能说明 3 | ✅ 已实现（12 周） |
| 日 / 周 / 月 / 年 / 全部粒度切换 | 功能说明 3 | 🟡 部分 |
| 每日目标达成记录、连续天数 | changelog | ✅ 连续天数已实现；达成日历 ⬜ |
| 阅读计时（纸书 / 其他 App 时长） | changelog | ⬜ 待实现 |
| 统计导出 CSV / PDF | 功能说明 3 | ⬜ 待实现 |
| 阅读成就勋章、合成海报 | changelog、`assets/images/achievement/*` | ⬜ 待实现 |
| 统计日历独立页、年度目标 | changelog | 🟡 年度目标设置已留 |

## 7. AI 助手

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 多轮对话、书籍总结、背景查询 | 功能说明 4 | ✅ 已实现（OpenAI 兼容 chat completions，按书保存历史） |
| 供应商预设 | `assets/images/ai_providers/` | ✅ 30+ 家（DeepSeek / 通义 / 智谱 / Kimi / Groq / OpenRouter / Ollama…），模型名是输入建议而非固定集合 |
| 用户自带密钥 | 功能说明 4 | ✅ 密钥单独存放，不参与备份与同步，界面只显示脱敏值 |
| 错误按原因分类 | — | ✅ 401 密钥错、429 稍后再试、5xx 带上游消息，三者处理方式不同 |
| 自定义请求头、Responses 协议 | changelog | ⬜ 待实现 |
| 角色关系图、角色身份与头像 | changelog、`assets/share/templates/character_relation.html` | ⬜ 待实现 |
| 结合书籍内容生成笔记灵感 | 功能说明 4 | ⬜ 待实现 |

## 8. 听书

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 系统离线 TTS | 功能说明 9 | ✅ 已实现 |
| 语速 / 音调 / 音量、断点续播 | 功能说明 9 | ✅ 语速音调已实现；断点续播 🟡 |
| 自动连读下一章 | — | ✅ 已实现 |
| 微软在线 TTS / 自定义 HTTP 朗读接口 | 功能说明 9 | ⬜ 待实现 |
| 多角色音色（旁白 / 男 / 女 / 对白） | `assets/images/audiobook/roles/*` | ⬜ 待实现 |
| 听书皮肤（封面纱幕等） | changelog、`assets/icons/audiobook/play_plate_*` | ⬜ 待实现 |

## 9. 云同步与数据

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| WebDAV 同步 | 功能说明 8、`icons/cloud/webdav.svg` | ✅ 已实现（PROPFIND / MKCOL / PUT / GET / DELETE，按 local name 匹配命名空间） |
| S3 / 兼容对象存储 | 功能说明 8、`icons/cloud/s3.svg` | ✅ 已实现（SigV4，路径风格，AWS 官方向量校验） |
| 同步粒度 | — | ✅ 一本书一份文档，冲突只影响一本 |
| 同步范围 | — | ✅ 书目 / 进度 / 笔记 / 设置；不含书籍文件、封面、密钥、统计 |
| 删除传播 | — | ⬜ 未实现（无墓碑，删掉的条目下次同步会被云端拉回） |
| Dropbox / Google Drive / OneDrive / iCloud | `icons/cloud/*` | ⬜ 待实现 |
| 百度网盘 / 123 云盘 | `icons/cloud/baidupan.png`、`pan123.png` | ⬜ 待实现 |
| 手动上传图库 / 字体 / 词典资源 | changelog | ⬜ 待实现 |
| 账号密码同步 | changelog | ⬜ 待实现 |
| 导出 / 导入书籍笔记与阅读记录 | changelog | ⬜ 待实现 |

## 10. OCR

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 图片识别文字 | `libmlkit_google_ocr_pipeline.so`、`play-services-mlkit-text-recognition-chinese` | ✅ 已实现（交给用户自配的识别服务，接口是 `{image, language}`） |
| 识别结果存为书籍 | — | ✅ 已实现（走现有导入管线，阅读器/笔记/进度直接可用） |
| 端上模型 | 同上 | ⬜ 待实现（接口已留，换一个 `recognize` 实现即可） |
| 拍照直接识别、多页连续识别 | changelog | ⬜ 待实现 |

## 11. 分享与导出

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 15 套分享模板（书单、封面、笔记、书评、统计、年度目标、人物关系…） | `assets/share/templates/*.html` | ⬜ 待实现 |
| 加密分享主题（限制保存 / 二次分享） | changelog | ⬜ 待实现 |
| 边框花纹图库（导入、管理、按内容摘要去重） | Reeden「我的图库」/「底栏图集」 | ✅ 已实现 |
| 九宫格切割设计器 | Reeden 卡片边框设计器 | ✅ 已实现 |
| 三种伸缩方式（全部 / 水平 / 垂直） | Reeden 文案「全部：橫豎都能拉…」 | ✅ 已实现 |
| 原图显示比例 | Reeden 文案「百分比越小，边框花纹越细」 | ✅ 已实现 |
| 绿线拖拽定可拉伸区域 | Reeden 文案「拖拽绿色选区选择允许拉伸的原图区域」 | ✅ 已实现 |
| 橙框拖拽定安全区 | Reeden 文案「橙色框是卡片里文字和图标能占的范围」 | ✅ 已实现 |
| 卡片装不下四角时整图等比缩小 | Reeden 文案「卡片小到裝不下四個角時…」 | ✅ 已实现 |
| 笔记海报渲染与导出 | 功能说明书 5.2 | ⬜ 待实现 |

## 12. 编辑与工具

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| TXT / EPUB 编辑器、段落高亮 | changelog | ⬜ 待实现 |
| EPUB 标点整理、章节管理、源码格式化 | changelog | ⬜ 待实现 |
| 书源 / 规则引擎 | `libfastdev_quickjs_runtime.so`、`packages/flutter_js/` | ✅ 已实现（声明式：CSS 选择器 + 正则，**不执行脚本**） |
| 书源书按章懒加载 | — | ✅ 已实现（目录导入时落库，正文按章抓取并缓存） |
| 书源 JSON 导入导出 | — | ✅ 已实现（同名同地址去重） |
| 书源脚本（QuickJS） | `libfastdev_quickjs_runtime.so` | ❌ 不做（能执行任意代码的书源等于交出设备） |
| 数学公式渲染 | `packages/flutter_math_fork/` | ⬜ 待实现 |

---

---

## 13. 更新与分发（GoodReader 自有能力）

| 功能 | 说明 | 状态 |
| --- | --- | --- |
| 检查更新 | 读取 GitHub Releases API，按语义化版本比较，展示更新说明 | ✅ 已实现 |
| 下载 APK | 优先选择 universal 包，其次 arm64，带进度显示 | ✅ 已实现 |
| 安装更新 | 通过 FileProvider 交给系统安装器（需授予「安装未知应用」） | ✅ 已实现 |
| 浏览器兜底 | 无法安装时可在浏览器打开 Release 页面 | ✅ 已实现 |
| 自动构建 | push 触发 analyze + test + 构建；打 `v*` tag 自动发 Release | ✅ 已实现 |

## 里程碑规划

| 版本 | 主题 | 内容 |
| --- | --- | --- |
| **v0.1** | 核心阅读 | 书架、TXT/EPUB 引擎、阅读器、排版、笔记、统计、TTS、设置、CI 出包 |
| **v0.2** | 阅读器细节 | 翻页动画、边缘手势、页眉页脚宏、首字下沉、版框、目录搜索、读完页 |
| **v0.3**（当前） | 阅读器补全 | 简繁转换、上下滚动、双指缩放、墨水屏模式、翻页音效、更新检测与安装 |
| v0.4 | 格式扩容 | PDF（pdfium）、MOBI/AZW3、CBZ/CBR 漫画、漫画模式、图片背景主题 |
| v0.5 | 数据与同步 | WebDAV、S3、导出/导入备份、全库正文搜索、Wi-Fi 传书 |
| v0.6 | AI 助手 | 多供应商 BYO-Key、书籍总结/问答、角色关系图 |
| v0.7 | 听书与 OCR | 在线 TTS、多角色音色、MLKit OCR 拍书 |
| v0.8 | 社交与成就 | 分享海报模板、成就勋章、年度报告、统计导出 |
| v0.9 | 高级工具 | 书源脚本引擎、EPUB/TXT 编辑器、数学公式渲染 |

## 阅读器侧剩余项（明确未完成）

以下目标 App 具备、GoodReader 尚未实现的阅读器能力，按优先级排列：

1. **双页模式** — 平板/横屏左右两页对照（需要重构页码模型）
2. **弹注** — EPUB 脚注解析与弹窗
3. **书内链接跳转 + 返回原处** — 需要解析章节内锚点
4. **替换规则** — 正文正则替换（需要与 `DisplayTransform` 组合的偏移映射）
5. **离线词典 + 生词高亮** — 需要词典数据与词形还原
6. **页面信息块** — 页面任意位置放置文字与装饰的可视化编辑器
7. **竖排 / 从右往左** — 设置项已预留
8. **掌阅墨水屏水波纹翻页** — 需要 shader
9. **跨章无缝滚动** — 当前上下滚动为章节内连续滚动
10. **PDF 裁边、方向锁定、自由旋转** — 依赖 PDF 引擎

## 非目标

- 不复制目标应用的代码、图标、字体、音效、模板等任何素材
- 不使用其品牌名、包名或商店素材
- 不实现绕过付费、破解授权相关的能力

## 下一批计划（按目标 App 的 UI 拆解产出）

来自 `E:\GITHUB\reeden\docs\reeden-ui-teardown\11-遗漏与补遗.md` 的 26 个功能面清单。
已按「不依赖外部服务、可完整验证」筛过一轮：

| 计划 | 说明 | 优先级 |
| --- | --- | --- |
| 7 个桌面小组件 | Glance/RemoteViews：书架、在读书单、当前在读、每日书摘、阅读热力图、阅读统计、周统计。文案已从 `resources.arsc` 完整取出 | 高 |
| 可切换启动图标 | manifest 里 18 个 activity-alias（9 配色 × 2 风格） | 高 |
| 精排系统 UI | 三级作用域规则 + 分组 + 拖拽排序 + 叠加语义 + 数值宏/尺寸宏 | 高 |
| EPUB 编辑器 UI | 章节多选、拖拽排序、合并、拆分、重命名、分卷、目录 | 中 |
| 笔记海报渲染导出 | 用已完成的边框切割模型渲染划线海报并存图 | 中 |
| 年度阅读报告 | 文案与图表已从字符串池取出 | 低 |

**明确不做**（依赖外部服务或超出阅读器范围）：内购与三家支付、Google 登录、
AI 助手、OCR、WebView 书源脚本、WebDAV/S3 云同步、Wi-Fi 传书、mDNS 发现。
