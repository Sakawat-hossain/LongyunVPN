#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shlobj.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Point WebView2 at a per-user, writable folder.
//
// By default WebView2 puts its user data directory next to the executable. For
// an installed build that is C:\Program Files\LongyunVPN, which a standard user
// cannot write to, so creating the in-app browser fails outright with
// "Microsoft Edge can't read and write to its data directory". Redirect it to
// %LOCALAPPDATA%\LongyunVPN\WebView2, which is always writable and survives
// upgrades. Must be set before any WebView2 environment is created, so it lives
// here rather than in Dart.
void SetWebView2UserDataFolder() {
  PWSTR local_app_data = nullptr;
  if (FAILED(::SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr,
                                    &local_app_data))) {
    return;
  }
  std::wstring folder(local_app_data);
  ::CoTaskMemFree(local_app_data);
  folder += L"\\LongyunVPN\\WebView2";
  // Ignore failures: if the directory already exists that is success, and if it
  // genuinely cannot be created WebView2 reports the problem itself.
  ::SHCreateDirectoryExW(nullptr, folder.c_str(), nullptr);
  ::SetEnvironmentVariableW(L"WEBVIEW2_USER_DATA_FOLDER", folder.c_str());
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  SetWebView2UserDataFolder();

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"LongyunVPN", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
