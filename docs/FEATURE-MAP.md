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
| 上下滚动阅读 | changelog | ⬜ 待实现 |
| 自动翻页（5/10/20/30/60 秒） | 功能说明 11.4 | ✅ 已实现 |
| 左侧上下滑动调亮度 | 主流阅读器通用交互 | ✅ 已实现（含 HUD 指示器） |
| 右侧上下滑动调音量 | 主流阅读器通用交互 | ✅ 已实现（含 HUD 指示器） |
| 阅读时保持屏幕常亮 | — | ✅ 已实现 |
| 双指缩放 | changelog | ⬜ 待实现 |
| 竖排阅读、从右往左 | changelog | 🟡 设置项已留；渲染 ⬜ |
| 简繁转换（台湾正体 / 香港繁体） | changelog | ⬜ 待实现 |
| 页眉页脚自定义（8 个宏：书名/章节/卷名/本章进度/全书进度/页码/时间/电量） | changelog「页眉页脚支持显示卷名-章节名，自定义模板新增卷名宏」 | ✅ 已实现 |
| 页面信息块 / 页面装饰 | changelog「支持页面信息块」 | ⬜ 待实现 |
| 版框（无 / 细线 / 外细内粗） | changelog「版框新增外细内粗样式」 | ✅ 已实现 |
| 首字下沉 | changelog「修复首字下沉后从首字往后划选会跳过旁边第一排文字」 | ✅ 已实现 |
| 读完页（加标签 / 回到开头） | changelog「优化读完页，可以直接给书加标签」 | ✅ 已实现 |
| 全文搜索 + 搜索历史（可逐条删除 / 清空） | 功能说明 11.3、changelog「优化搜索历史」 | ✅ 已实现 |
| 书内链接跳转、跳转后返回原处 | changelog | ⬜ 待实现 |
| 弹注（脚注弹窗） | changelog「部分书籍标题上的弹注图标点不开」 | ⬜ 待实现 |
| 双页模式 | changelog「双页模式下章首页的划线点不开」 | ⬜ 待实现 |
| 墨水屏模式 | changelog「优化墨水屏模式，开关即时生效」 | ⬜ 待实现 |
| 离线词典、生词高亮 | changelog | ⬜ 待实现 |
| 替换规则（正文替换） | changelog「优化替换规则」 | ⬜ 待实现 |
| 漫画模式（整屏看图） | changelog | ⬜ 待实现 |
| PDF 裁边、方向锁定、自由旋转 | changelog | ⬜ 待实现 |
| 翻页音效 | `assets/audio/page_turn/*.wav` | ⬜ 待实现 |

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
| 多轮对话、书籍总结、背景查询、推荐 | 功能说明 4 | ⬜ 待实现 |
| 40+ 家 AI 供应商预设 | `assets/images/ai_providers/`（OpenAI、Claude、Gemini、DeepSeek、通义、智谱、Kimi、Ollama…） | ⬜ 待实现 |
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
| WebDAV 同步 | 功能说明 8、`icons/cloud/webdav.svg` | ⬜ 待实现 |
| S3 / 兼容对象存储 | 功能说明 8、`icons/cloud/s3.svg` | ⬜ 待实现 |
| Dropbox / Google Drive / OneDrive / iCloud | `icons/cloud/*` | ⬜ 待实现 |
| 百度网盘 / 123 云盘 | `icons/cloud/baidupan.png`、`pan123.png` | ⬜ 待实现 |
| 手动上传图库 / 字体 / 词典资源 | changelog | ⬜ 待实现 |
| 账号密码同步 | changelog | ⬜ 待实现 |
| 导出 / 导入书籍笔记与阅读记录 | changelog | ⬜ 待实现 |

## 10. OCR

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 拍照识别文字并导入 | `libmlkit_google_ocr_pipeline.so`、`play-services-mlkit-text-recognition-chinese` | ⬜ 待实现 |

## 11. 分享与导出

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| 15 套分享模板（书单、封面、笔记、书评、统计、年度目标、人物关系…） | `assets/share/templates/*.html` | ⬜ 待实现 |
| 加密分享主题（限制保存 / 二次分享） | changelog | ⬜ 待实现 |

## 12. 编辑与工具

| 功能 | 来源 | 状态 |
| --- | --- | --- |
| TXT / EPUB 编辑器、段落高亮 | changelog | ⬜ 待实现 |
| EPUB 标点整理、章节管理、源码格式化 | changelog | ⬜ 待实现 |
| 书源 / 规则脚本引擎 | `libfastdev_quickjs_runtime.so`、`packages/flutter_js/` | ⬜ 待实现 |
| 数学公式渲染 | `packages/flutter_math_fork/` | ⬜ 待实现 |

---

## 里程碑规划

| 版本 | 主题 | 内容 |
| --- | --- | --- |
| **v0.1**（当前） | 核心阅读 | 书架、TXT/EPUB 引擎、阅读器、排版、笔记、统计、TTS、设置、CI 出包 |
| v0.2 | 格式扩容 | PDF（pdfrx/pdfium）、MOBI/AZW3、CBZ/CBR 漫画、封面填充模式 |
| v0.3 | 阅读体验 | 翻页动画（仿真 / 翻书 / 水波纹）、翻页音效、双指缩放、简繁转换、竖排 |
| v0.4 | 数据与同步 | WebDAV、S3、导出/导入备份、全库正文搜索、Wi-Fi 传书 |
| v0.5 | AI 助手 | 多供应商 BYO-Key、书籍总结/问答、角色关系图 |
| v0.6 | 听书与 OCR | 在线 TTS、多角色音色、MLKit OCR 拍书 |
| v0.7 | 社交与成就 | 分享海报模板、成就勋章、年度报告、统计导出 |
| v0.8 | 高级工具 | 书源脚本引擎、EPUB/TXT 编辑器、数学公式渲染 |

## 非目标

- 不复制目标应用的代码、图标、字体、音效、模板等任何素材
- 不使用其品牌名、包名或商店素材
- 不实现绕过付费、破解授权相关的能力
