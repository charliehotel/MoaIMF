<p align="center">
  <a href="README.md">🇰🇷 한국어</a> | <a href="README.en.md">🇺🇸 English</a> | <a href="README.ja.md">🇯🇵 日本語</a> | <a href="README.zh-Hans.md">🇨🇳 简体中文</a> | <a href="README.zh-Hant.md">🇹🇼 繁體中文</a> | <a href="README.vi.md">🇻🇳 Tiếng Việt</a>
  <br>
  <a href="README.fr.md">🇫🇷 Français</a> | <a href="README.de.md">🇩🇪 Deutsch</a> | <a href="README.es.md">🇪🇸 Español</a> | <a href="README.pt.md">🇵🇹 Português</a> | <a href="README.th.md">🇹🇭 ไทย</a> | <a href="README.ar.md">🇸🇦 العربية</a>
</p>

<p align="center">
  <img src="../Assets.xcassets/MoaIMF_icon.png" width="128" height="128" alt="Biểu tượng MoaIMF">
</p>

<h1 align="center">MoaIMF</h1>

<p align="center">
  <strong>Initial. Medial. Final. Composed.</strong><br>
  Ứng dụng thanh menu macOS giúp chuẩn hóa an toàn tên tệp Unicode bị tách rời sang dạng NFC hoàn chỉnh
</p>

<p align="center">
  <a href="#giới-thiệu">Giới thiệu</a> ·
  <a href="#cách-sử-dụng">Cách sử dụng</a> ·
  <a href="#cài-đặt-và-build">Cài đặt và build</a> ·
  <a href="#an-toàn-và-quyền-riêng-tư">An toàn</a> ·
  <a href="#phát-triển">Phát triển</a>
</p>

## Giới thiệu

MoaIMF là ứng dụng thanh menu macOS chuẩn hóa tên tệp và thư mục trong các thư mục do người dùng chọn sang Unicode NFC. Tên ứng dụng nói đến việc gom Initial, Medial và Final của một âm tiết Hangul thành một ký tự hoàn chỉnh.

Trên macOS, tên tệp tiếng Hàn có thể bị lưu ở dạng tách rời giống NFD sau khi đi qua hệ thống tệp, ứng dụng, công cụ tải xuống, công cụ giải nén, ổ ngoài, NAS hoặc công cụ đồng bộ đám mây. Khi đó Finder có thể hiển thị `한글.txt`, nhưng Alfred, tìm kiếm trong terminal hoặc một số script tự động hóa lại nhìn thấy `ㅎㅏㄴㄱㅡㄹ.txt` và không tìm được tệp.

MoaIMF không coi đây là một script dọn dẹp chạy một lần. Ứng dụng theo dõi liên tục các thư mục đã được người dùng cho phép và sửa vấn đề tên của các tệp mới được tạo hoặc tải xuống, hoàn toàn cục bộ.

## Ảnh chụp màn hình

Đây là màn hình chính của ứng dụng thanh menu. Khi đang theo dõi thư mục, biểu tượng trên thanh menu chuyển lần lượt qua `ㅎ`, `ㅏ`, `ㄴ`, `한`. Khi tạm dừng, biểu tượng dừng ở `ㅎ`.

<table>
  <tr>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_ko.gif" alt="Hoạt ảnh thanh menu MoaIMF tiếng Hàn" width="100%"></kbd>
    </td>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_en.png" alt="Màn hình thanh menu MoaIMF tiếng Anh" width="100%"></kbd>
    </td>
  </tr>
</table>

### Cài đặt thư mục theo dõi

<kbd><img src="../Screenshots/MoaIMF_monitoring_folders_en.png" alt="Cài đặt thư mục theo dõi" width="100%"></kbd>

Cài đặt thư mục theo dõi bắt đầu từ `Downloads` theo mặc định. Bạn có thể thêm hoặc xóa thư mục bằng nút `+` và `-`. Mỗi thư mục có thể bật hoặc tắt riêng, và thư mục bị mất quyền có thể được chọn lại.

### Ngoại lệ ổn định tải xuống

<kbd><img src="../Screenshots/MoaIMF_exceptions_en.png" alt="Ngoại lệ ổn định tải xuống" width="100%"></kbd>

Tệp đang tải xuống có thể chưa có tên cuối cùng, hoặc kích thước và thời gian sửa đổi vẫn đang thay đổi. MoaIMF cung cấp các quy tắc khóa sẵn cho `.crdownload`, `.download`, `.part`, `.partial`, `.tmp`, đồng thời cho phép thêm quy tắc ngoại lệ riêng.

Quy tắc tùy chỉnh hỗ trợ tên tệp chính xác, hậu tố hoặc phần mở rộng, và glob `*`, `?` cho thành phần cuối của đường dẫn. Mục khớp quy tắc sẽ bị giữ lại cho đến khi quy tắc bị xóa hoặc mục đó biến mất.

### Lịch sử gần đây

<kbd><img src="../Screenshots/MoaIMF_recent_history_en.png" alt="Lịch sử gần đây" width="100%"></kbd>

Lịch sử gần đây có thể xem theo hôm nay, 7 ngày, 30 ngày hoặc toàn bộ thời gian, và lọc theo đổi tên, xung đột, quyền hoặc lỗi. Ô tìm kiếm so sánh cả biến thể chuẩn hóa để coi khác biệt NFC/NFD là cùng một nhập liệu.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/history.jsonl
```

### Giới thiệu ứng dụng

<kbd><img src="../Screenshots/MoaIMF_about_en.png" alt="Giới thiệu MoaIMF" width="100%"></kbd>

Cửa sổ About hiển thị tên ứng dụng, phiên bản, mô tả ngắn và bản quyền. Hình phía trên minh họa ý tưởng ghép jamo đã tách thành ký tự hoàn chỉnh, như `ㅎㅏㄴ -> 한`.

## Tính năng chính

- Kiểm tra trạng thái theo dõi từ thanh menu, tạm dừng, tiếp tục và thoát
- Dùng Downloads làm vị trí theo dõi mặc định
- Thêm và xóa nhiều thư mục theo dõi bằng `+` và `-`
- Quét đệ quy thư mục theo dõi và thư mục con
- Chỉ truy cập thư mục người dùng đã chọn bằng security-scoped bookmarks
- Phát hiện tệp mới và đường dẫn thay đổi bằng FSEvents
- Chỉ xử lý sau khi kích thước và thời gian sửa đổi ổn định
- Không tự động ghi đè khi có khả năng xung đột
- Lưu đổi tên, xung đột, quyền, ngắt kết nối và lỗi hệ thống tệp vào lịch sử
- Không có máy chủ bên ngoài, đăng nhập tài khoản hoặc telemetry

## Cách hoạt động

MoaIMF không thay đổi nội dung tệp. Ứng dụng chỉ xử lý dạng chuẩn hóa Unicode của tên tệp và thư mục.

Luồng xử lý: người dùng chọn thư mục, ứng dụng lưu quyền truy cập bằng bookmark, FSEvents báo thay đổi, dịch vụ quét kiểm tra ngoại lệ và độ ổn định, tính tên đích NFC, kiểm tra xung đột, xác minh danh tính tệp trước và sau khi rename, rồi lưu kết quả vào lịch sử gần đây.

Nhờ vậy, MoaIMF không tự ý gộp tệp có khả năng xung đột và không tự tạo tên như `-1`, `copy` hay `복사본`. Trường hợp cần người dùng quyết định sẽ được ghi lại trong lịch sử và thông báo.

## Cách sử dụng

1. Mở `MoaIMF.app`. Biểu tượng sẽ xuất hiện trên thanh menu thay vì ở lại Dock.
2. Mở `Watched Folder Settings...` và thêm thư mục cần theo dõi.
3. Khi thêm thư mục lần đầu, chọn `Normalize Existing Items` hoặc `Watch New Items Only`.
4. Dùng `Pause Watching` và `Resume Watching` để tạm dừng hoặc tiếp tục.
5. Dùng `Scan All Now` hoặc `Scan Now` theo từng thư mục để quét thủ công.
6. Chọn ngôn ngữ trong menu `Language`.
7. Bật `Launch at Login` nếu muốn MoaIMF chạy khi đăng nhập.
8. Chọn `Quit MoaIMF` để thoát. Ứng dụng không để lại daemon hoặc helper riêng.

Các ngôn ngữ được cung cấp là bản dịch AI để thuận tiện. Nếu thấy bản dịch sai hoặc muốn thêm ngôn ngữ khác, hãy báo qua `Issues`.

## Cài đặt và build

Tải `MoaIMF.dmg` từ GitHub Releases, mở tệp và sao chép `MoaIMF.app` vào `/Applications`. Bản release hiện chưa được ký Developer ID hoặc notarized bởi Apple. Nếu macOS chặn và bạn tin tưởng tệp đã tải, hãy gỡ thuộc tính quarantine rồi mở ứng dụng.

```sh
xattr -dr com.apple.quarantine /Applications/MoaIMF.app
open /Applications/MoaIMF.app
```

Nếu muốn build từ mã nguồn:

Yêu cầu:

- macOS 13 Ventura trở lên
- Xcode 16 hoặc Xcode Command Line Tools tương thích
- Swift 6 toolchain
- Git

```sh
git clone https://github.com/charliehotel/MoaIMF.git
cd MoaIMF
scripts/check.sh
open .build/MoaIMF.app
```

Chỉ build app bundle:

```sh
scripts/build-app.sh
```

## Vị trí dữ liệu cục bộ

MoaIMF lưu trạng thái ứng dụng và lịch sử trong Application Support bên trong sandbox container của ứng dụng macOS.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

Các tệp chính là `watched-folders.json`, `stability-rules.json`, `history.jsonl` và thư mục `recovery/`. Một số thiết lập cũng được lưu trong `UserDefaults`.

## An toàn và quyền riêng tư

MoaIMF chỉ đổi tên, không đọc hoặc sửa nội dung tệp. Ứng dụng chỉ truy cập thư mục người dùng đã chọn, không đi theo symbolic link, không quét bên trong package như `.app` hoặc `.photoslibrary`, kiểm tra xung đột trước khi đổi tên và xử lý hoàn toàn cục bộ. Không có mạng, đăng nhập tài khoản, analytics hay telemetry.

## Giới hạn

MoaIMF không thay đổi cách macOS lưu tên tệp trên toàn hệ thống, không ép mọi ứng dụng lưu tên ở NFC, không tự gộp tệp xung đột, không tái tạo trực tiếp chỉ mục Spotlight hoặc Alfred, và hiện tập trung vào build từ mã nguồn.

## Gỡ cài đặt

1. Tắt `Launch at Login`.
2. Chọn `Quit MoaIMF`.
3. Xóa `MoaIMF.app`.
4. Nếu muốn xóa trạng thái cục bộ, xóa thư mục Application Support của MoaIMF trong app container.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

Việc này không đổi các tên đã chuyển sang NFC trở lại NFD.

## Phát triển

Dự án dùng Swift Package Manager.

```sh
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
swift build
scripts/build-app.sh
```

- [Đặc tả thiết kế v0.1](../docs/superpowers/specs/2026-06-21-moaimf-v0.1-design.md)
- [Kế hoạch triển khai v0.1](../docs/superpowers/plans/2026-06-21-moaimf-v0.1.md)
- [Hướng dẫn đóng góp](../CONTRIBUTING.md)
- [Chính sách bảo mật](../SECURITY.md)

## Giấy phép

MoaIMF được phân phối theo [MIT License](../LICENSE).
