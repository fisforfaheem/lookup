#include "flutter_window.h"

#include <algorithm>
#include <cwctype>
#include <optional>
#include <string>
#include <vector>

#include <flutter/encodable_value.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

uint64_t GetIdleMillis() {
  LASTINPUTINFO info;
  info.cbSize = sizeof(LASTINPUTINFO);
  if (!GetLastInputInfo(&info)) {
    return 0;
  }

  return GetTickCount64() - static_cast<uint64_t>(info.dwTime);
}

std::wstring ToLower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(), [](wchar_t c) {
    return static_cast<wchar_t>(std::towlower(c));
  });
  return value;
}

bool ContainsAny(const std::wstring& haystack,
                 const std::vector<std::wstring>& needles) {
  for (const auto& needle : needles) {
    if (haystack.find(needle) != std::wstring::npos) {
      return true;
    }
  }
  return false;
}

bool IsFullscreenWindow(HWND hwnd) {
  if (hwnd == nullptr) {
    return false;
  }

  RECT window_rect;
  if (!GetWindowRect(hwnd, &window_rect)) {
    return false;
  }

  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  if (monitor == nullptr) {
    return false;
  }

  MONITORINFO monitor_info;
  monitor_info.cbSize = sizeof(MONITORINFO);
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    return false;
  }

  const RECT monitor_rect = monitor_info.rcMonitor;
  const int tolerance = 2;

  return std::abs(window_rect.left - monitor_rect.left) <= tolerance &&
         std::abs(window_rect.top - monitor_rect.top) <= tolerance &&
         std::abs(window_rect.right - monitor_rect.right) <= tolerance &&
         std::abs(window_rect.bottom - monitor_rect.bottom) <= tolerance;
}

std::string DetectHighEngagement() {
  HWND foreground = GetForegroundWindow();
  if (foreground == nullptr) {
    return "none";
  }

  wchar_t title[512];
  GetWindowTextW(foreground, title, 512);

  wchar_t class_name[256];
  GetClassNameW(foreground, class_name, 256);

  std::wstring token = ToLower(std::wstring(title) + L" " + std::wstring(class_name));

  if (ContainsAny(token, {L"zoom", L"teams", L"meet", L"webex"})) {
    return "meeting";
  }

  if (ContainsAny(token, {L"obs", L"record", L"screen share"})) {
    return "screenShare";
  }

  if (ContainsAny(token, {L"youtube", L"netflix", L"vlc", L"mpv"})) {
    return "videoPlayback";
  }

  if (IsFullscreenWindow(foreground)) {
    return "fullscreenApp";
  }

  return "none";
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  activity_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "lookup/activity",
          &flutter::StandardMethodCodec::GetInstance());

  activity_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "getActivitySnapshot") {
          result->NotImplemented();
          return;
        }

        flutter::EncodableMap payload;
        payload[flutter::EncodableValue("idleMillis")] =
            flutter::EncodableValue(static_cast<int64_t>(GetIdleMillis()));
        payload[flutter::EncodableValue("highEngagement")] =
            flutter::EncodableValue(DetectHighEngagement());
        payload[flutter::EncodableValue("isFrontmost")] =
            flutter::EncodableValue(true);

        result->Success(flutter::EncodableValue(payload));
      });

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
