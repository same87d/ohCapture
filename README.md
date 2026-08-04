# ohCapture

ohCapture 是一款轻量、开源的 macOS 截图工具。它支持区域截图和窗口吸附，并可直接读取被其他窗口遮挡的窗口内容，无需改变当前窗口层级。

> 当前项目处于 MVP 开发阶段，暂不提供预编译安装包，需要从源码构建。

## 已实现功能

- `Shift + Option + 1` 选择并截取窗口
- `Shift + Option + 2` 拖动框选截图区域
- `Shift + Option + 鼠标左键拖动` 快速框选截图区域
- 选择窗口时光标悬停自动吸附
- 使用 ScreenCaptureKit 截取被遮挡的完整窗口，不将窗口移到最前方
- 箭头、矩形、文字和马赛克标注
- 复制到剪贴板或保存为 PNG

截图内容不会上传到第三方服务器。

## 系统与开发环境

- 运行截图及标注功能：macOS 14 或更高版本
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

脚本即使通过 `sudo` 启动，也会使用当前登录用户构建源码，只在复制应用时使用管理员权限，避免产生 root 所有的构建缓存。

## 首次运行与权限

ohCapture 首次截图时需要“屏幕与系统音频录制”权限：

1. 打开“系统设置 → 隐私与安全性 → 屏幕与系统音频录制”。
2. 允许 ohCapture 访问屏幕内容。
3. 完全退出并重新打开 ohCapture。

如果全局快捷键没有响应，请确认应用仍在菜单栏运行。

## 使用方法

1. 按 `Shift + Option + 1` 进入 **Capture Selected Window**，将光标移到窗口上并单击；窗口即使被遮挡，也不会被移动到最前方。
2. 按 `Shift + Option + 2` 进入 **Capture Selected Portion**，然后拖动选择截图区域。
3. 按住 `Shift + Option` 并直接用鼠标左键拖动，可通过 **Fast Capture** 快速选择截图区域。
4. 完成截图后，在浮动工具栏中进行标注、复制或保存。

### 工具栏

- **Arrow**：绘制箭头
- **Rect**：绘制矩形
- **Mosaic**：拖动涂抹敏感区域
- **Text**：单击图片后输入文字
- **Undo**：撤销最近一次标注
- **Copy**：复制带标注的截图并关闭预览
- **Save**：保存带标注的 PNG 并关闭预览
- **Close**：放弃当前截图

### 快捷操作

- `Enter`：复制截图
- `Command + S`：保存截图
- `Command + Z`：撤销标注
- `Escape`：取消截图或关闭预览

## 从源码测试

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache" \
swift test --disable-sandbox
```

## 开源许可

本项目使用 [MIT License](LICENSE)。
