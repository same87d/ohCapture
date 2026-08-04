# ohCapture

ohCapture 是一款轻量、开源的 macOS 截图工具。它支持区域截图和窗口吸附，并可直接读取被其他窗口遮挡的窗口内容，无需改变当前窗口层级。

> 当前项目处于 MVP 开发阶段，暂不提供预编译安装包，需要从源码构建。

## 已实现功能

- `Option + Shift + 2` 全局快捷键呼出截图
- 拖动框选任意区域
- 光标悬停时自动吸附窗口
- 使用 ScreenCaptureKit 截取被遮挡的完整窗口，不将窗口移到最前方
- 箭头、矩形、文字和马赛克标注
- 复制到剪贴板或保存为 PNG
- 使用 Apple Vision 在本机进行 OCR，识别结果直接复制
- 使用 Apple Translation 在本机翻译截图文字（macOS 26 及以上）

截图、OCR 文字和翻译内容均不会上传到第三方服务器。

## 系统与开发环境

- 运行截图及标注功能：macOS 14 或更高版本
- 运行截图翻译功能：macOS 26 或更高版本
- 从源码构建：Xcode 26 或更高版本，且已安装 Command Line Tools

首次构建前，可用以下命令确认 Swift 环境：

```sh
xcode-select -p
swift --version
```

## 构建并运行

```sh
git clone https://github.com/same87d/ohCapture.git
cd ohCapture
./scripts/build.sh
open build/ohCapture.app
```

构建完成的应用位于 `build/ohCapture.app`。

## 安装到“应用程序”

下面的脚本会重新构建应用，并复制到 `/Applications/ohCapture.app`：

```sh
sudo ./scripts/install.sh
open /Applications/ohCapture.app
```

## 首次运行与权限

ohCapture 首次截图时需要“屏幕与系统音频录制”权限：

1. 打开“系统设置 → 隐私与安全性 → 屏幕与系统音频录制”。
2. 允许 ohCapture 访问屏幕内容。
3. 完全退出并重新打开 ohCapture。

如果全局快捷键没有响应，请确认应用仍在菜单栏运行。

## 使用方法

1. 按 `Option + Shift + 2`，或点击菜单栏图标并选择 **Interactive Capture**。
2. 将光标移到窗口上，单击即可截取该窗口的完整内容；窗口即使被遮挡，也不会被移动到最前方。
3. 按住鼠标拖动，可自由框选截图区域。
4. 松开鼠标后，在浮动工具栏中进行标注、OCR、翻译、复制或保存。

### 工具栏

- **Arrow**：绘制箭头
- **Rect**：绘制矩形
- **Text**：单击图片后输入文字
- **Mosaic**：拖动涂抹敏感区域
- **OCR**：识别截图文字并复制到剪贴板
- **Translate**：OCR 后自动翻译并复制译文；中文翻译为英文，其他语言翻译为简体中文
- **Undo**：撤销最近一次标注
- **Copy**：复制带标注的截图并关闭预览
- **Save**：保存带标注的 PNG 并关闭预览
- **Close**：放弃当前截图

### 快捷操作

- `Enter`：复制截图
- `Command + S`：保存截图
- `Command + Z`：撤销标注
- `Escape`：取消截图或关闭预览

## 本机翻译说明

翻译功能依赖 macOS 自带的 Apple Translation 框架和本机语言模型。首次使用前，请在“系统设置 → 通用 → 语言与地区 → 翻译语言”中安装需要的语言。

## 从源码测试

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache" \
swift test --disable-sandbox
```

## 开源许可

本项目使用 [MIT License](LICENSE)。
