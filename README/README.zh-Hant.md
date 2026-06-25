<p align="center">
  <a href="README.md">🇰🇷 한국어</a> | <a href="README.en.md">🇺🇸 English</a> | <a href="README.ja.md">🇯🇵 日本語</a> | <a href="README.zh-Hans.md">🇨🇳 简体中文</a> | <a href="README.zh-Hant.md">🇹🇼 繁體中文</a> | <a href="README.vi.md">🇻🇳 Tiếng Việt</a>
  <br>
  <a href="README.fr.md">🇫🇷 Français</a> | <a href="README.de.md">🇩🇪 Deutsch</a> | <a href="README.es.md">🇪🇸 Español</a> | <a href="README.pt.md">🇵🇹 Português</a> | <a href="README.th.md">🇹🇭 ไทย</a> | <a href="README.ar.md">🇸🇦 العربية</a>
</p>

<p align="center">
  <img src="../Assets.xcassets/MoaIMF_icon.png" width="128" height="128" alt="MoaIMF 圖示">
</p>

<h1 align="center">MoaIMF</h1>

<p align="center">
  <strong>Initial. Medial. Final. Composed.</strong><br>
  將分解的 Unicode 檔名安全整理為 NFC 組合形式的 macOS 選單列 App
</p>

<p align="center">
  <a href="#介紹">介紹</a> ·
  <a href="#使用方式">使用方式</a> ·
  <a href="#安裝與建置">安裝與建置</a> ·
  <a href="#安全與隱私">安全性</a> ·
  <a href="#開發">開發</a>
</p>

## 介紹

MoaIMF 是一款 macOS 選單列 App，可將使用者指定資料夾中的檔名與資料夾名稱正規化為 Unicode NFC。名稱的意思是把韓文字節的初聲(Initial)、中聲(Medial)、終聲(Final)組合成完整的組合字元(Composed)。

在 macOS 上，韓文檔名經過檔案系統、App、下載工具、解壓縮工具、外接儲存裝置、NAS 或雲端同步工具後，可能會以類似 NFD 的分解形式儲存。這種情況下，Finder 中看起來像 `한글.txt`，但 Alfred、終端機搜尋和部分自動化腳本可能會把它辨識為 `ㅎㅏㄴㄱㅡㄹ.txt`，導致找不到檔案。

MoaIMF 不把這個問題視為一次性的清理腳本。它是只在本機執行的工具，會持續監視使用者核准的資料夾，並修正新建立或下載檔案的名稱問題。

## 截圖

這是選單列 App 的主畫面。監視資料夾時，選單列圖示會依序變成 `ㅎ`、`ㅏ`、`ㄴ`、`한`。暫停監視時，圖示會停在 `ㅎ`。

<table>
  <tr>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_ko.gif" alt="MoaIMF 韓文選單列動畫" width="100%"></kbd>
    </td>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_en.png" alt="MoaIMF 英文選單列畫面" width="100%"></kbd>
    </td>
  </tr>
</table>

### 監視資料夾設定

<kbd><img src="../Screenshots/MoaIMF_monitoring_folders_en.png" alt="監視資料夾設定" width="100%"></kbd>

監視資料夾設定以 `Downloads` 資料夾作為預設起點。你可以用 `+` 與 `-` 按鈕新增或移除監視資料夾。每個資料夾都可以個別啟用或停用，權限中斷的資料夾也可以重新選擇。

按下資料夾旁的 `Scan Now` 會立即掃描該資料夾。掃描結果會顯示 NFC 項目、NFD 候選項、衝突和保留項目，因此可以清楚知道實際檢查了什麼。

### 下載穩定性例外

<kbd><img src="../Screenshots/MoaIMF_exceptions_en.png" alt="下載穩定性例外" width="100%"></kbd>

正在下載的檔案可能尚未確定最終名稱，檔案大小與修改時間也可能持續變動。MoaIMF 將 `.crdownload`、`.download`、`.part`、`.partial`、`.tmp` 等基本規則作為鎖定規則提供，並允許使用者新增自己的例外規則。

支援的使用者規則如下：

- 精確檔名
- 後綴或副檔名
- 針對最後一個路徑組成部分的 `*`、`?` glob

符合例外規則的項目，在規則被移除或項目消失之前不會被處理。包含例外項目的上層資料夾也會一併保留，避免過早重新命名仍在下載中的資料夾。

### 最近記錄

<kbd><img src="../Screenshots/MoaIMF_recent_history_en.png" alt="最近記錄" width="100%"></kbd>

最近記錄可依今天、7 天、30 天、全部期間查看，也可以依重新命名、衝突、權限、錯誤類型篩選。搜尋欄會搜尋檔案路徑、處理原因、事件標題和根識別碼，並比較正規化變體，把 NFC/NFD 拼寫差異視為同一個使用者輸入。

記錄會儲存為本機 JSONL 檔案。

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/history.jsonl
```

記錄預設保留 30 天。新增記錄時，超過保留期限的項目會被整理。

### 關於

<kbd><img src="../Screenshots/MoaIMF_about_en.png" alt="關於 MoaIMF" width="100%"></kbd>

About 視窗會顯示 App 名稱、版本、簡短說明和著作權資訊。上方圖片展示了像 `ㅎㅏㄴ -> 한` 這樣將分解字母合成完整字元的概念。

## 主要功能

- 在選單列查看監視狀態，並可暫停、繼續、結束
- 預設監視位置為 Downloads
- 使用 `+` 與 `-` 新增或刪除多個監視資料夾
- 遞迴檢查監視資料夾及其子資料夾
- 僅透過安全範圍書籤存取使用者選擇的資料夾
- 使用 FSEvents 偵測新檔案或變更的路徑
- 僅在檔案大小與修改時間穩定後處理
- 保留下載中的中間檔與使用者自訂例外規則
- 將檔名與資料夾名稱正規化為 Unicode NFC
- 可能發生衝突時絕不自動覆寫
- 直接 rename 驗證失敗時使用可復原的臨時名稱策略
- 將變更、衝突、權限、中斷連線、檔案系統錯誤儲存到最近記錄
- 在選單顯示今天修正的檔案數，並可前往最近記錄
- 首次啟動時顯示尋找選單列圖示的提示
- 顯示登入時自動啟動的註冊狀態
- 支援 App 內語言選擇
- 沒有外部伺服器通訊、帳號登入或遙測

## 運作方式

MoaIMF 不會變更檔案內容。它只處理檔名與資料夾名稱的 Unicode 正規化形式。

處理流程如下：

1. 使用者選擇要監視的資料夾。
2. App 將該資料夾的存取權限儲存為安全範圍書籤。
3. FSEvents 通知新檔案、新資料夾、重新命名、下載完成等變化。
4. 掃描服務檢查該路徑與下層項目。
5. 檢查例外規則、套件、符號連結目標、權限問題和檔案穩定狀態。
6. 發現 NFD 等非 NFC 名稱時，計算 NFC 目標名稱。
7. 檢查同一資料夾內是否存在正規化後同名的項目。
8. 只有沒有衝突且已穩定的項目會成為重新命名候選。
9. 變更前再次確認檔案身分並執行 rename。
10. 變更後驗證實際檔名是否以 NFC 位元組保存。
11. 將結果儲存到最近記錄，並更新選單中今天的修正數。

因此，MoaIMF 不會任意合併疑似衝突的檔案，也不會自動建立 `-1`、`copy`、`복사본` 這類新名稱。需要使用者判斷的情況會保留在最近記錄與通知中。

## 使用方式

### 1. 啟動 App

啟動 `MoaIMF.app` 後，它不會像一般 App 一樣長時間停留在 Dock，而是會在選單列顯示圖示。如果選單列圖示很多，或圖示可能被 MacBook 瀏海遮住，首次啟動時會顯示提示視窗。

### 2. 設定監視資料夾

從選單開啟 `Watched Folder Settings...`。預設資料夾是 Downloads。需要時用 `+` 按鈕新增其他資料夾。

建議使用方式如下：

- 將 Downloads 等經常產生新檔案的位置登錄為監視對象。
- 專案原始碼、照片圖庫、App bundle 等結構敏感的位置只在必要時登錄。
- 外接磁碟或 NAS 同步資料夾應先用少量檔案測試。

### 3. 選擇既有項目的處理方式

第一次新增資料夾時，可以選擇是否立即處理既有項目，或只監視之後新產生的項目。

- `Normalize Existing Items`：檢查目前資料夾中已存在的 Non-NFC 名稱，並重新命名已核准的候選項。
- `Watch New Items Only`：保留既有檔名，只處理之後新建或變更的項目。

如果資料夾中已有大量檔案，先查看掃描結果再處理會比較安全。

### 4. 暫停與繼續

選單中的 `Pause Watching` 會停止監視與自動重新命名。設定、記錄和資料夾列表會保留。暫停期間，選單列圖示動畫也會停止並顯示初始影格。

要重新處理，請選擇 `Resume Watching`。

### 5. 立即掃描

`Scan All Now` 會重新掃描所有已登錄的監視資料夾。監視資料夾設定畫面中每一列的 `Scan Now` 只會掃描該資料夾。

手動掃描適用於以下情況：

- App 未執行時新增了檔案
- 重新連接外接磁碟
- 修改例外規則後想重新檢查保留項目
- 想比較最近記錄與實際資料夾狀態

### 6. 變更語言

可在選單的 `Language` 中直接選擇 App 顯示語言。目前可手動選擇的語言如下：

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

提供的語言是為了方便使用的 AI 翻譯。如果發現翻譯錯誤，或希望新增其他語言，請透過 `Issues` 告訴我們。

### 7. 登入時啟動

在選單中開啟 `Launch at Login` 後，MoaIMF 會登錄為 macOS 登入項目。選單也會顯示目前登錄狀態。如果 macOS 要求使用者核准，請開啟系統設定並核准。

### 8. 結束

選擇 `Quit MoaIMF` 後，App 會整理監視工作與安全範圍存取，然後結束。不會留下獨立的 daemon 或 helper 程序。

## 安裝與建置

目前假定以原始碼建置安裝。尚未提供經 Developer ID 簽署與 Apple 公證的發佈檔案。

### 需求

- macOS 13 Ventura 或更新版本
- Xcode 16 或相容的 Xcode Command Line Tools
- Swift 6 toolchain
- Git

建置腳本也會使用 macOS 基本工具。

- `swift`
- `xcrun swift-format`
- `sips`
- `python3`
- `codesign`
- `ditto`

執行時不需要額外伺服器、資料庫或網路 API。

### 取得儲存庫

```sh
git clone https://github.com/charliehotel/MoaIMF.git
cd MoaIMF
```

儲存庫位址可能會依實際公開位置調整。

### 檢查與建置

要一次執行完整檢查、測試與 App bundle 產生，請使用：

```sh
scripts/check.sh
```

只建置 App bundle：

```sh
scripts/build-app.sh
```

產生的 App 位於：

```text
.build/MoaIMF.app
```

本機執行：

```sh
open .build/MoaIMF.app
```

`scripts/build-app.sh` 產生的是本機測試用的 ad-hoc 簽署 App。若要分發到其他 Mac，需要另外設定 Developer ID 簽署與 notarization。

## 本機資料位置

MoaIMF 將 App 狀態與記錄儲存在 macOS App 沙盒容器內的 Application Support。

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

`<app bundle identifier>` 取決於已安裝 App build 中包含的 bundle identifier。

主要檔案如下：

| 檔案 | 說明 |
|---|---|
| `watched-folders.json` | 監視資料夾列表、啟用狀態、安全範圍書籤 |
| `stability-rules.json` | 下載穩定性基本規則與使用者例外規則 |
| `history.jsonl` | 最近處理記錄 |
| `recovery/` | 重新命名失敗時用於復原的日誌 |

部分 App 設定也會儲存在 `UserDefaults` 中，例如暫停狀態、語言選擇、是否隱藏首次啟動提示。

## 安全與隱私

MoaIMF 的基本原則是：「只安全地改名，不確定就停止。」

- 不讀取或修改檔案內容。
- 只存取使用者選擇的資料夾。
- 使用安全範圍書籤遵循 macOS 權限模型。
- 不檢查 `.app`、`.bundle`、`.framework`、`.photoslibrary` 等套件內部。
- 不跟隨符號連結目標。
- 如果正規化後同一資料夾內會出現同名項目，則不變更。
- 重新命名前後都會驗證檔案身分。
- 如果檔案系統不保留已驗證的 NFC 名稱，會將該情況記錄為錯誤。
- 所有處理都在本機完成。
- 沒有網路通訊、帳號登入、分析事件或遙測。

## 限制

- MoaIMF 不會改變 macOS 全域的檔名儲存方式。
- 不會強制所有 App 都以 NFC 儲存檔名。
- 不會自動合併衝突檔案，也不會用新名稱自動解決衝突。
- 不會直接重建 Spotlight 或 Alfred 索引。
- 如果檔案系統、同步工具或外接儲存裝置再次改寫名稱位元組，App 無法自動復原所有情況。
- 目前主要面向原始碼建置與本機測試 App bundle。
- 尚未提供自動更新、App Store 分發或已公證 DMG 分發。

## 移除

1. 在選單中關閉 `Launch at Login`。
2. 在選單中選擇 `Quit MoaIMF`。
3. 刪除已安裝的 `MoaIMF.app`。
4. 若也要刪除本機狀態，請刪除 App 容器內的 MoaIMF Application Support 資料夾。

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

`<app bundle identifier>` 取決於已安裝 App build 中包含的 bundle identifier。

此操作不會把已經改為 NFC 的檔名還原為 NFD。

## 開發

專案基於 Swift Package Manager。

```text
Sources/
  MoaIMFCore/   正規化、掃描、監視、儲存、安全 rename 引擎
  MoaIMFUI/     AppController、選單、設定、記錄、About、本地化
  MoaIMFApp/    macOS App 入口點與選單列標籤
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

為了減少 sandbox 或快取權限問題，建議使用 `scripts/check.sh`。該腳本會將 SwiftPM 快取與模組快取指定到 `.build/` 下。

設計文件：

- [v0.1 設計規格](../docs/superpowers/specs/2026-06-21-moaimf-v0.1-design.md)
- [v0.1 實作計畫](../docs/superpowers/plans/2026-06-21-moaimf-v0.1.md)
- [貢獻指南](../CONTRIBUTING.md)
- [安全政策](../SECURITY.md)

## 授權

MoaIMF 以 [MIT License](../LICENSE) 發布。
