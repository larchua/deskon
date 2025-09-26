## Deskon 本地开发与打包操作手册（含 VS2022 组件清单）

本手册面向在本地构建与打包 Deskon 的开发者，提供可直接复制粘贴的命令。默认仓库路径：`D:\DeskOn\deskon`。

### 内容概览
- Windows 环境搭建与构建（重点），含 Visual Studio 2022 组件清单
- Linux/macOS 桌面构建
- Android/iOS 移动端构建
- 常用诊断命令

---

## 一、安装与准备（Windows，PowerShell）

本节按“从零开始”的顺序描述需要安装的软件与基础配置。完成后你将拥有用于构建 Deskon 的工具链。

1. 安装 Visual Studio 2022（或已安装）

- 在安装器中选择工作负载："使用 C++ 的桌面开发（Desktop development with C++）"。
- 推荐组件：MSVC v143、Windows 10/11 SDK、CMake for Windows、C++ 核心功能。按需勾选 ATL/MFC、WiX 等。

2. 安装基础工具（可用 Chocolatey 自动安装）

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
choco install -y git cmake ninja visualstudio2022buildtools visualstudio2022-workload-vctools wixtoolset
```

3. 安装 Rust（MSVC toolchain）

```powershell
winget install -e --id Rustlang.Rustup
# 重新打开 PowerShell 后：
rustup default stable-x86_64-pc-windows-msvc
rustc -V
cargo -V
```

4. 安装并配置 Flutter

```powershell
# 建议解压 Flutter SDK 到 D:\flutter，将 D:\flutter\bin 加入 PATH
flutter --version
flutter doctor
flutter config --enable-windows-desktop
```

---

## 二、初始化仓库与子模块（一步到位）

在你准备好的开发环境中，克隆仓库并初始化子模块：

```powershell
cd D:\MyProject\Deskon\deskon-git
git submodule sync --recursive
git submodule update --init --recursive
```

如果存在损坏或空的子模块目录，请先清理再拉：

```powershell
Remove-Item -Recurse -Force .\libs\hbb_common -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .\libs\scrap -ErrorAction SilentlyContinue
git submodule update --init --recursive
```

---

## 三、配置 vcpkg 与安装本机依赖

Deskon 使用 vcpkg 来管理 FFmpeg、libvpx、opus 等本机依赖，仓库采用 vcpkg 的 manifest（`vcpkg.json`）和 overlay ports（`res/vcpkg`）。

1) 安装 vcpkg（只需一次）：

```powershell
cd D:\
git clone https://github.com/microsoft/vcpkg.git
.\vcpkg\bootstrap-vcpkg.bat

[Environment]::SetEnvironmentVariable("VCPKG_ROOT", "D:\\vcpkg", "User")
[Environment]::SetEnvironmentVariable("VCPKG_DEFAULT_TRIPLET", "x64-windows-static", "User")
$env:VCPKG_ROOT="D:\\vcpkg"
$env:VCPKG_DEFAULT_TRIPLET="x64-windows-static"
```

2) 在仓库根以 manifest 模式安装依赖：

```powershell
cd D:\MyProject\Deskon\deskon-git
$env:VCPKG_FEATURE_FLAGS="manifests"
& "$env:VCPKG_ROOT\vcpkg.exe" install
```

3) 验证关键包安装：

```powershell
& "$env:VCPKG_ROOT\vcpkg.exe" list | Select-String "opus|libvpx|libyuv|ffmpeg|aom|libjpeg-turbo"
```

注意：vcpkg 的 `installed` 目录应包含 `include` 与 `lib`。若 `installed` 布局异常，见 Troubleshooting 小节。

---

## 四、生成桥接并构建 Rust 内核

在构建 Flutter 应用之前，必须先构建 Rust 后端：

```powershell
cd D:\MyProject\Deskon\rustdesk
cargo build --release
```


1) 生成 flutter_rust_bridge 桥接代码（接口变更或首次执行时）：

```powershell
cd D:\MyProject\Deskon\rustdesk\flutter
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid
~\.cargo\bin\flutter_rust_bridge_codegen.exe --rust-input ..\src\flutter_ffi.rs --dart-output .\lib\generated_bridge.dart --c-output .\windows\runner\bridge_generated.h
```

2) 构建 Rust 内核（启用 flutter 特性）：

```powershell
cd D:\MyProject\Deskon\rustdesk
cargo build --features flutter
```

如果构建失败提示缺少头文件或库（例如 `opus/opus_multistream.h`、`vpx/vp8.h`），请参见 Troubleshooting 阶段。

---

## 五、Flutter：拉取依赖并运行 / 打包

### 前置条件：确保 Rust 后端已构建

在构建 Flutter 应用之前，必须先构建 Rust 后端：

```powershell
cd D:\MyProject\Deskon\rustdesk
cargo build --release
```

### Flutter 构建步骤

1) 拉取 Flutter 依赖：

```powershell
cd D:\MyProject\Deskon\rustdesk\flutter
flutter pub get
```

2) 清理构建缓存（推荐）：

```powershell
flutter clean
```

3) 发布构建（推荐方式）：

```powershell
flutter build windows
```

4) 运行构建好的应用：

```powershell
.\build\windows\x64\runner\Release\rustdesk.exe
```

### 调试运行（可选）

如果需要调试模式运行，可以尝试：

```powershell
flutter run -d windows
```

**注意**：对于 RustDesk 这样的混合项目（Rust + Flutter），直接使用 `flutter run` 可能会遇到 CMake 安装错误。推荐使用 `flutter build windows` 然后直接运行生成的可执行文件。

### 产物路径

构建成功后，可执行文件位于：`D:\MyProject\Deskon\rustdesk\flutter\build\windows\x64\runner\Release\rustdesk.exe`

---

## 六、打包与可选步骤

- 可选：使用 WiX 打包 MSI（需安装 WiX Toolset）：

```powershell
cd D:\MyProject\Deskon\deskon-git\res\msi
candle.exe product.wxs
light.exe -ext WixUIExtension product.wixobj -o deskon.msi
```

- 仅构建 Rust 内核：

```powershell
cd D:\MyProject\Deskon\deskon-git
cargo build
cargo build --release
```

---

## 七、故障排查与常用诊断（Troubleshooting）

### vcpkg 引起的常见构建失败（排查与解决）

问题概述：
- 在 Windows 上使用 `cargo build --features flutter` 构建 Rust 内核时，构建脚本通常通过 vcpkg 的 `installed` 目录（例如 `D:\vcpkg\installed\x64-windows-static\include`）查找头文件和链接库。如果该 `installed` 布局缺失或未按预期被填充，编译会在类似于 `fatal error: 'opus/opus_multistream.h' file not found` 或 `fatal error: 'vpx/vp8.h' file not found` 的错误处止步，进而导致 `flutter build windows` 失败（因为缺少 `libdeskon.dll`）。

排查步骤（PowerShell）：

1) 确认 vcpkg 环境变量：

```powershell
$env:VCPKG_ROOT
$env:VCPKG_DEFAULT_TRIPLET
```

2) 在仓库根运行 manifest 模式的安装，并观察输出：

```powershell
cd D:\MyProject\Deskon\deskon-git
$env:VCPKG_FEATURE_FLAGS="manifests"
& "$env:VCPKG_ROOT\vcpkg.exe" install
```

3) 检查 vcpkg 的 `installed` 目录是否包含头文件和 lib：

```powershell
Test-Path "D:\vcpkg\installed\x64-windows-static\include\opus\opus_multistream.h"
Test-Path "D:\vcpkg\installed\x64-windows-static\include\vpx\vp8.h"
Get-ChildItem "D:\vcpkg\installed\x64-windows-static\include" -Directory -ErrorAction SilentlyContinue
```

vp8、opus、libvpx、libyuv、ffmpeg、aom、libjpeg-turbo、scrap

常见情况与解决方案：

- 情况 A：vcpkg 报告安装成功，但 `D:\vcpkg\installed\x64-windows-static` 目录不存在或为空
  - 可能原因：vcpkg 的安装根与当前会话使用的 `VCPKG_ROOT` 不一致，或使用了自定义 overlay ports 并未正确生成 `installed` 布局。
  - 解决：确保环境变量正确并在仓库根以 manifests 模式重新安装；如果需要临时绕过，可创建一个 junction（目录链接）将 vcpkg 的 `installed` 指向正确位置：

```powershell
if (-not (Test-Path 'D:\vcpkg\installed')) {
    cmd /c mklink /J "D:\vcpkg\installed" "D:\MyProject\Deskon\deskon-git\vcpkg_installed"
}
```

---

### Flutter Windows 构建错误（CMake 安装失败）

问题概述：
- 在运行 `flutter run -d windows` 时遇到 MSBuild 错误，错误信息包含 `cmake.exe -DBUILD_TYPE=Debug -P cmake_install.cmake` 失败，退出代码为 1。
- 这通常发生在混合项目（Rust + Flutter）中，特别是当 Rust 后端尚未构建或构建缓存存在问题时。

常见错误信息：
```
C:\BuildTools\MSBuild\Microsoft\VC\v170\Microsoft.CppCommon.targets(166,5): error MSB3073: 
命令"setlocal [D:\MyProject\Deskon\rustdesk\flutter\build\windows\x64\INSTALL.vcxproj]
C:\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe -DBUILD_TYPE=Debug -P cmake_install.cmake
```

解决步骤：

1) 确保 Rust 后端已构建：

```powershell
cd D:\MyProject\Deskon\rustdesk
cargo build --release
```

2) 清理 Flutter 构建缓存：

```powershell
cd D:\MyProject\Deskon\rustdesk\flutter
flutter clean
```

3) 使用构建命令而非运行命令：

```powershell
# 推荐：先构建再运行
flutter build windows
.\build\windows\x64\runner\Release\rustdesk.exe

# 而不是直接运行（可能失败）
# flutter run -d windows
```

4) 验证环境：

```powershell
# 检查 Flutter 环境
flutter doctor -v

# 检查 Visual Studio 构建工具
where msbuild
```

**注意**：对于 RustDesk 项目，推荐的工作流程是先构建 Rust 后端，然后使用 `flutter build windows` 构建 Flutter 前端，最后直接运行生成的可执行文件。

---

### 10. 可选：打包 MSI（WiX）
```powershell
# 前提：已安装 WiX Toolset v3（candle/light 需在 PATH）
cd D:\MyProject\Deskon\deskon\res\msi

# 示例命令（按实际 .wxs 名称调整）
candle.exe product.wxs | cat
light.exe -ext WixUIExtension product.wixobj -o deskon.msi | cat
```
不熟悉 WiX 时，可直接分发 `flutter build windows` 的 Release 目录或压缩为 zip。

### 11. 仅构建 Rust 内核（可选）
```powershell
cd D:\MyProject\Deskon\deskon-git
cargo build
cargo build --release
```

### 12. 常见问题
```powershell
# Flutter 不识别 Windows 桌面
flutter config --enable-windows-desktop
flutter doctor

# vcpkg 未生效（当前会话）
$env:VCPKG_ROOT="D:\\vcpkg"
$env:VCPKG_DEFAULT_TRIPLET="x64-windows-static"

# 如果需要网络代理（可选）
$env:HTTP_PROXY="http://127.0.0.1:7890"
$env:HTTPS_PROXY="http://127.0.0.1:7890"
```

---

## 二、Linux 开发环境（Bash）

### 1. 系统依赖（Debian/Ubuntu 示例）
```bash
sudo apt update
sudo apt install -y build-essential git cmake ninja-build pkg-config curl \
  libgtk-3-dev libayatana-appindicator3-dev
```

### 2. 安装 Rust、Flutter
```bash
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env

# 自行解压 Flutter SDK 并加入 PATH
flutter --version
flutter doctor
flutter config --enable-linux-desktop
```

### 3. 安装 vcpkg
```bash
cd ~
git clone https://github.com/microsoft/vcpkg.git
./vcpkg/bootstrap-vcpkg.sh
echo 'export VCPKG_ROOT=$HOME/vcpkg' >> ~/.bashrc
echo 'export VCPKG_DEFAULT_TRIPLET=x64-linux' >> ~/.bashrc
source ~/.bashrc
```

### 4. 构建依赖并运行
```bash
cd /path/to/deskon
$VCPKG_ROOT/vcpkg install

cd flutter
flutter pub get
flutter run -d linux
flutter build linux
```

### 5. 打包（任选）
- AppImage（`appimage/*.yml`）
```bash
pipx install appimage-builder
cd /path/to/deskon/appimage
appimage-builder --recipe AppImageBuilder-x86_64.yml
```
- Flatpak（`flatpak/`）
```bash
cd /path/to/deskon/flatpak
flatpak-builder build-dir com.deskon.Deskon.metainfo.xml --force-clean
```

---

## 三、macOS 开发环境（zsh/Bash）

### 1. 安装依赖
```bash
xcode-select --install
brew install cmake ninja git
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env
flutter --version
flutter doctor
flutter config --enable-macos-desktop
```

### 2. 安装 vcpkg
```bash
cd ~
git clone https://github.com/microsoft/vcpkg.git
./vcpkg/bootstrap-vcpkg.sh
echo 'export VCPKG_ROOT=$HOME/vcpkg' >> ~/.zshrc
echo 'export VCPKG_DEFAULT_TRIPLET=arm64-osx' >> ~/.zshrc  # Intel 使用 x64-osx
source ~/.zshrc
```

### 3. 构建依赖并运行
```bash
cd /path/to/deskon
$VCPKG_ROOT/vcpkg install

cd flutter
flutter pub get
flutter run -d macos
flutter build macos
```

### 4. 打包（示例生成 DMG）
```bash
brew install create-dmg
create-dmg --overwrite --volname "Deskon" Deskon.dmg build/macos/Build/Products/Release/Deskon.app
```

---

## 四、Android 构建

### 1. 准备
```bash
# 安装 Android Studio，安装 SDK/NDK/CMake
flutter doctor --android-licenses
```

### 2. 构建与运行
```bash
cd /path/to/deskon/flutter
flutter pub get
flutter build apk
# 或构建 App Bundle：
flutter build appbundle
flutter devices
flutter run -d <device_id>
```

### 3. 可选：仓库脚本（依赖 Bash 环境）
```bash
cd /path/to/deskon/flutter
./build_android_deps.sh
./build_android.sh
```

---

## 五、iOS 构建（需 macOS）

### 1. 准备
```bash
sudo gem install cocoapods
cd /path/to/deskon/flutter/ios
pod install
```

### 2. 构建
```bash
cd /path/to/deskon/flutter
flutter pub get
flutter build ios
```
使用 Xcode 打开 `Runner.xcworkspace` 配置签名，选择真机/模拟器运行或归档上传。

---

## 六、常用诊断命令

```powershell
# Windows
flutter doctor -v | cat
cmake --version
ninja --version
cargo -V
$env:VCPKG_ROOT
$env:VCPKG_DEFAULT_TRIPLET
```

```bash
# Linux/macOS
flutter doctor -v
cmake --version
ninja --version
cargo -V
echo $VCPKG_ROOT
echo $VCPKG_DEFAULT_TRIPLET
```

---

## 七、Windows 常见报错与修复指引

### A. 运行时报 `generated_bridge.dart` 丢失、`RustdeskImpl` 未定义
现象：
- Error when reading 'lib/generated_bridge.dart': 找不到指定的文件
- Type 'RustdeskImpl' not found / isn't a type

原因：未先生成 flutter_rust_bridge 桥接代码，或未先编译启用 `flutter` 特性的 Rust 内核。





# 3) 回到 flutter，拉包并运行
cd D:\MyProject\Deskon\deskon-git\flutter
flutter pub get
flutter run -d windows

# 如仍失败，先清理后重试
flutter clean
```

### B. Flutter/插件类型不匹配（如 DialogTheme、extended_text 报错）
现象示例：
- The argument type 'DialogTheme' can't be assigned to 'DialogThemeData?'
- extended_text 某些类缺少实现

原因：Flutter SDK 与依赖版本不匹配。

建议升级到最新稳定版 Flutter：
```powershell
flutter channel stable
flutter upgrade
flutter --version
cd D:\DeskOn\deskon\flutter
flutter pub get
```
如仍有问题，尝试：
```powershell
flutter pub upgrade --major-versions
```

### C. PowerShell 将输出管道给 `cat` 报 ParameterBindingException
现象：执行 `... | cat` 报 `InputObjectNotBound`。

原因：PowerShell 的 `cat` 是 `Get-Content`，不接收这种对象管道。

处理：不要在 PowerShell 中给 vcpkg 或其他命令追加 `| cat`。直接执行：
```powershell
& "$env:VCPKG_ROOT\vcpkg.exe" install
```

### D. `file_picker` 平台默认实现告警
说明：是告警非错误，通常不影响 Windows 运行，可忽略。

### E. 代码生成工具报 CargoMetadata 错误，提示找不到 `libs/hbb_common/Cargo.toml`
现象：
- flutter_rust_bridge_codegen 报错：failed to read `...libs\hbb_common\Cargo.toml`（os error 2）

原因：Git 子模块未初始化或未同步，导致 `libs/hbb_common`、`libs/scrap` 等子模块未拉取。

修复：
```powershell
cd D:\MyProject\Deskon\deskon-git
git submodule sync --recursive
git submodule update --init --recursive
# 可验证：cargo metadata --format-version 1 --no-deps | Select-String deskon
```
若仍报相同错误，删除空的子模块目录后重拉：
```powershell
Remove-Item -Recurse -Force .\libs\hbb_common -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .\libs\scrap -ErrorAction SilentlyContinue
git submodule update --init --recursive
```

