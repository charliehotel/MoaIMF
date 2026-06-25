[🇰🇷 한국어](README.md) | [🇺🇸 English](README.en.md) | [🇯🇵 日本語](README.ja.md) | [🇨🇳 简体中文](README.zh-Hans.md) | [🇹🇼 繁體中文](README.zh-Hant.md) | [🇻🇳 Tiếng Việt](README.vi.md)<br>
[🇫🇷 Français](README.fr.md) | [🇩🇪 Deutsch](README.de.md) | [🇪🇸 Español](README.es.md) | [🇵🇹 Português](README.pt.md) | [🇹🇭 ไทย](README.th.md) | [🇸🇦 العربية](README.ar.md)


<p align="center">
  <img src="../Assets.xcassets/MoaIMF_icon.png" width="128" height="128" alt="MoaIMF 图标">
</p>

<h1 align="center">MoaIMF</h1>

<p align="center">
  <strong>Initial. Medial. Final. Composed.</strong><br>
  将分解的 Unicode 文件名安全整理为 NFC 组合形式的 macOS 菜单栏应用
</p>

<p align="center">
  <a href="#简介">简介</a> ·
  <a href="#使用方法">使用方法</a> ·
  <a href="#安装与构建">安装与构建</a> ·
  <a href="#安全与隐私">安全性</a> ·
  <a href="#开发">开发</a>
</p>

## 简介

MoaIMF 是一款 macOS 菜单栏应用，可将用户指定文件夹中的文件名和文件夹名规范化为 Unicode NFC。名称的含义是把韩文字节的初声(Initial)、中声(Medial)、终声(Final)组合成完整的组合字符(Composed)。

在 macOS 上，韩文文件名经过文件系统、应用、下载工具、解压工具、外置存储、NAS 或云同步工具后，可能以类似 NFD 的分解形式保存。这种情况下，Finder 中看起来像 `한글.txt`，但 Alfred、终端搜索和某些自动化脚本可能会把它识别为 `ㅎㅏㄴㄱㅡㄹ.txt`，从而找不到文件。

MoaIMF 不把这个问题当作一次性清理脚本来处理。它是一个仅在本地运行的工具，会持续监视用户批准的文件夹，并修复新创建或下载文件的名称问题。

## 截图

这是菜单栏应用的主界面。监视文件夹时，菜单栏图标会按 `ㅎ`、`ㅏ`、`ㄴ`、`한` 的顺序变化。暂停监视时，图标会停在 `ㅎ`。

<table>
  <tr>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_ko.gif" alt="MoaIMF 韩文菜单栏动画" width="100%"></kbd>
    </td>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_en.png" alt="MoaIMF 英文菜单栏界面" width="100%"></kbd>
    </td>
  </tr>
</table>

### 监视文件夹设置

<kbd><img src="../Screenshots/MoaIMF_monitoring_folders_en.png" alt="监视文件夹设置" width="100%"></kbd>

监视文件夹设置以 `Downloads` 文件夹作为默认起点。你可以用 `+` 和 `-` 按钮添加或移除监视文件夹。每个文件夹都可以单独启用或停用，权限失效的文件夹也可以重新选择。

点击某个文件夹的 `Scan Now` 会立即扫描该文件夹。扫描结果会显示 NFC 项、NFD 候选项、冲突和待处理项，因此可以清楚看到实际检查了什么。

### 下载稳定性例外

<kbd><img src="../Screenshots/MoaIMF_exceptions_en.png" alt="下载稳定性例外" width="100%"></kbd>

正在下载的文件可能还没有最终文件名，文件大小和修改时间也可能仍在变化。MoaIMF 将 `.crdownload`、`.download`、`.part`、`.partial`、`.tmp` 等基本规则作为锁定规则提供，并允许用户添加自己的例外规则。

支持的用户规则如下：

- 精确文件名
- 后缀或扩展名
- 针对最后一个路径组成部分的 `*`、`?` glob

匹配例外规则的项目在规则被移除或该项目消失之前不会处理。包含例外项目的上级文件夹也会一并暂缓，避免过早重命名正在下载中的文件夹。

### 最近记录

<kbd><img src="../Screenshots/MoaIMF_recent_history_en.png" alt="最近记录" width="100%"></kbd>

最近记录可以按今天、7 天、30 天和全部时间查看，也可以按重命名、冲突、权限和错误类型筛选。搜索框会搜索文件路径、处理原因、事件标题和根标识符，并比较规范化变体，把 NFC/NFD 拼写差异视为同一用户输入。

记录保存为本地 JSONL 文件。

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/history.jsonl
```

记录默认保留 30 天。添加新记录时，超过保留期限的项目会被清理。

### 关于

<kbd><img src="../Screenshots/MoaIMF_about_en.png" alt="关于 MoaIMF" width="100%"></kbd>

About 窗口会显示应用名称、版本、简短说明和版权信息。顶部图片展示了像 `ㅎㅏㄴ -> 한` 这样把分解字母合成为完整字符的概念。

## 主要功能

- 在菜单栏查看监视状态，并可暂停、恢复、退出
- 默认监视位置为 Downloads
- 使用 `+` 和 `-` 添加或删除多个监视文件夹
- 递归检查监视文件夹及其子文件夹
- 只通过安全范围书签访问用户选择的文件夹
- 使用 FSEvents 检测新文件和路径变化
- 仅在文件大小和修改时间稳定后处理
- 暂缓下载中间文件和用户自定义例外规则
- 将文件名和文件夹名规范化为 Unicode NFC
- 存在冲突可能时绝不自动覆盖
- 直接 rename 验证失败时使用可恢复的临时名称策略
- 将重命名、冲突、权限、断开连接和文件系统错误保存到最近记录
- 在菜单中显示今天修复的文件数，并可跳转到最近记录
- 首次启动时显示查找菜单栏图标的提示
- 显示登录时自动启动的注册状态
- 支持应用内语言选择
- 没有外部服务器通信、账号登录或遥测

## 工作方式

MoaIMF 不修改文件内容。它只处理文件名和文件夹名的 Unicode 规范化形式。

处理流程如下：

1. 用户选择要监视的文件夹。
2. 应用将该文件夹的访问权限保存为安全范围书签。
3. FSEvents 通知新文件、新文件夹、重命名、下载完成等变化。
4. 扫描服务检查该路径及其子项目。
5. 检查例外规则、包、符号链接目标、权限问题和文件稳定状态。
6. 发现 NFD 等非 NFC 名称时，计算 NFC 目标名称。
7. 检查同一文件夹内是否存在规范化后同名的项目。
8. 只有没有冲突且已稳定的项目才会成为重命名候选。
9. 重命名前再次确认文件身份并执行 rename。
10. 重命名后验证实际文件名是否以 NFC 字节保存。
11. 将结果保存到最近记录，并更新菜单中的今日修复数量。

因此，MoaIMF 不会擅自合并疑似冲突的文件，也不会自动创建 `-1`、`copy`、`복사본` 这样的新名称。需要用户判断的情况会留在最近记录和通知中。

## 使用方法

### 1. 启动应用

启动 `MoaIMF.app` 后，它不会像普通应用一样长期停留在 Dock 中，而是在菜单栏显示图标。如果菜单栏图标很多，或图标可能被 MacBook 刘海遮住，首次启动时会显示提示窗口。

### 2. 设置监视文件夹

从菜单打开 `Watched Folder Settings...`。默认文件夹是 Downloads。需要时用 `+` 按钮添加其他文件夹。

推荐用法如下：

- 将 Downloads 等经常产生新文件的位置注册为监视对象。
- 项目源码、照片图库、应用包等结构敏感的位置只在必要时注册。
- 外置磁盘或 NAS 同步文件夹应先用少量文件测试。

### 3. 选择已有项目处理方式

首次添加文件夹时，可以选择是否立即处理已有项目，或只监视以后新产生的项目。

- `Normalize Existing Items`：检查当前文件夹中已经存在的 Non-NFC 名称，并重命名已批准的候选项。
- `Watch New Items Only`：保留现有文件名，只处理之后新建或变更的项目。

如果文件夹中已有大量文件，最好先查看扫描结果再处理。

### 4. 暂停与恢复

选择菜单中的 `Pause Watching` 会停止监视和自动重命名。设置、记录和文件夹列表会保留。暂停期间，菜单栏图标动画也会停止并显示初始帧。

要重新处理，请选择 `Resume Watching`。

### 5. 立即扫描

`Scan All Now` 会重新扫描所有已注册的监视文件夹。监视文件夹设置界面中每一行的 `Scan Now` 只扫描对应文件夹。

手动扫描适用于以下情况：

- 应用未运行时添加了文件
- 重新连接了外置磁盘
- 更改例外规则后想重新检查待处理项目
- 想比较最近记录与实际文件夹状态

### 6. 更改语言

可在菜单的 `Language` 中直接选择应用显示语言。目前可手动选择的语言如下：

- System Default
- English
- 한국어
- 日本語
- 简体中文
- 繁體中文
- Tiếng Việt
- Français
- Deutsch
- Español
- Português
- ไทย
- العربية

提供的语言是为了方便使用的 AI 翻译。如果发现翻译错误，或希望增加其他语言，请通过 `Issues` 告诉我们。

### 7. 登录时启动

在菜单中开启 `Launch at Login` 后，MoaIMF 会注册为 macOS 登录项。菜单也会显示当前注册状态。如果 macOS 要求用户批准，请打开系统设置并批准。

### 8. 退出

选择 `Quit MoaIMF` 后，应用会清理监视任务和安全范围访问，然后退出。不会留下单独的 daemon 或 helper 进程。

## 安装与构建

目前假定通过源码构建安装。尚未提供经过 Developer ID 签名和 Apple 公证的发布文件。

### 要求

- macOS 13 Ventura 或更高版本
- Xcode 16 或兼容的 Xcode Command Line Tools
- Swift 6 toolchain
- Git

构建脚本还会使用 macOS 基本工具。

- `swift`
- `xcrun swift-format`
- `sips`
- `python3`
- `codesign`
- `ditto`

运行时不需要额外服务器、数据库或网络 API。

### 获取仓库

```sh
git clone https://github.com/charliehotel/MoaIMF.git
cd MoaIMF
```

仓库地址可能会按实际公开位置调整。

### 检查与构建

要一次运行完整检查、测试和应用包生成，请使用：

```sh
scripts/check.sh
```

只构建应用包：

```sh
scripts/build-app.sh
```

生成的应用位于：

```text
.build/MoaIMF.app
```

本地运行：

```sh
open .build/MoaIMF.app
```

`scripts/build-app.sh` 生成的是用于本地测试的 ad-hoc 签名应用。要分发到其他 Mac，需要另行配置 Developer ID 签名和 notarization。

## 本地数据位置

MoaIMF 将应用状态和记录保存到 macOS 应用沙盒容器内的 Application Support。

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

`<app bundle identifier>` 取决于已安装应用构建中包含的 bundle identifier。

主要文件如下：

| 文件 | 说明 |
|---|---|
| `watched-folders.json` | 监视文件夹列表、启用状态、安全范围书签 |
| `stability-rules.json` | 下载稳定性基本规则和用户例外规则 |
| `history.jsonl` | 最近处理记录 |
| `recovery/` | 重命名失败时用于恢复的日志 |

部分应用设置也保存在 `UserDefaults` 中，例如暂停状态、语言选择、是否隐藏首次启动提示。

## 安全与隐私

MoaIMF 的基本原则是：“只安全地改名，不确定就停止。”

- 不读取或修改文件内容。
- 只访问用户选择的文件夹。
- 使用安全范围书签遵循 macOS 权限模型。
- 不检查 `.app`、`.bundle`、`.framework`、`.photoslibrary` 等包内部。
- 不跟随符号链接目标。
- 如果规范化后同一文件夹内会出现同名项目，则不更改。
- 重命名前后都会验证文件身份。
- 如果文件系统不保留已验证的 NFC 名称，会将该情况记录为错误。
- 所有处理都在本地完成。
- 没有网络通信、账号登录、分析事件或遥测。

## 限制

- MoaIMF 不会改变 macOS 全局的文件名保存方式。
- 不会强制所有应用都以 NFC 保存文件名。
- 不会自动合并冲突文件，也不会用新名称自动解决冲突。
- 不会直接重建 Spotlight 或 Alfred 索引。
- 如果文件系统、同步工具或外置存储再次改写名称字节，应用无法自动恢复所有情况。
- 目前主要面向源码构建和本地测试应用包。
- 尚未提供自动更新、App Store 分发或已公证 DMG 分发。

## 移除

1. 在菜单中关闭 `Launch at Login`。
2. 在菜单中选择 `Quit MoaIMF`。
3. 删除已安装的 `MoaIMF.app`。
4. 如需同时删除本地状态，请删除应用容器内的 MoaIMF Application Support 文件夹。

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

`<app bundle identifier>` 取决于已安装应用构建中包含的 bundle identifier。

此操作不会把已经改为 NFC 的文件名还原为 NFD。

## 开发

项目基于 Swift Package Manager。

```text
Sources/
  MoaIMFCore/   规范化、扫描、监视、存储、安全 rename 引擎
  MoaIMFUI/     AppController、菜单、设置、记录、About、本地化
  MoaIMFApp/    macOS 应用入口和菜单栏标签
Tests/
  MoaIMFCoreTests/
  MoaIMFUITests/
```

常用命令：

```sh
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
swift build
scripts/build-app.sh
```

为了减少 sandbox 或缓存权限问题，建议使用 `scripts/check.sh`。该脚本会把 SwiftPM 缓存和模块缓存指定到 `.build/` 下。

设计文档：

- [v0.1 设计规范](../docs/superpowers/specs/2026-06-21-moaimf-v0.1-design.md)
- [v0.1 实现计划](../docs/superpowers/plans/2026-06-21-moaimf-v0.1.md)
- [贡献指南](../CONTRIBUTING.md)
- [安全政策](../SECURITY.md)

## 许可证

MoaIMF 以 [MIT License](../LICENSE) 发布。
