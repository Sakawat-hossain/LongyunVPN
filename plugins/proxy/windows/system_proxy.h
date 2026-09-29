// Windows system proxy: set it, and put back exactly what was there before.
//
// Header-only so the plugin and the app's own launcher (windows/runner) share
// one implementation. The launcher uses it for `--clear-system-proxy`, which the
// uninstaller runs: uninstall force-kills the app, so the normal exit path that
// clears the proxy never gets to run, and once the app is deleted there is
// nothing left that ever would.
//
// Three rules this file exists to enforce:
//
//   1. Only ever undo a proxy we set. "Stop" used to write DIRECT
//      unconditionally, and it runs on every launch - so opening the app to
//      check an account switched off a running Clash Verge, or a company proxy.
//
//   2. Put back what the user had, not a guess. "Start" has to write the flags
//      as exactly DIRECT|PROXY - WinINet consults auto-detect and PAC before a
//      manual proxy, so either would route around us - but "stop" never turned
//      them back on, so "Automatically detect settings" stayed off for good
//      after the first connect. Windows ships with it on.
//
//   3. Survive a crash. What we set and what was there before are recorded in
//      the registry, not in memory, so the next launch - or the uninstaller - can
//      still tell our proxy from anyone else's and restore the original.

#pragma once

#include <windows.h>

#include <WinInet.h>
#include <Ras.h>
#include <RasError.h>

#include <string>
#include <vector>

#pragma comment(lib, "wininet")
#pragma comment(lib, "Rasapi32")
#pragma comment(lib, "Advapi32")

namespace system_proxy {

// Where the record lives. Per-user, like the proxy setting itself.
inline constexpr wchar_t kRecordKey[] = L"Software\\LongyunVPN\\SystemProxy";

struct ConnectionState {
  bool ok = false;
  DWORD flags = PROXY_TYPE_DIRECT;
  std::wstring server;
  std::wstring bypass;
};

// What Windows ships with, used only when nothing better is known: a proxy of
// ours found with no record of what it replaced (left by a version of the app
// that did not keep one).
inline constexpr DWORD kWindowsDefaultFlags =
    PROXY_TYPE_DIRECT | PROXY_TYPE_AUTO_DETECT;

inline std::wstring OurServer(int port) {
  return L"127.0.0.1:" + std::to_wstring(port);
}

// ── Reading and writing the connection settings ─────────────────────────────

inline ConnectionState QueryDefaultConnection() {
  INTERNET_PER_CONN_OPTIONW options[3] = {};
  options[0].dwOption = INTERNET_PER_CONN_FLAGS;
  options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
  options[2].dwOption = INTERNET_PER_CONN_PROXY_BYPASS;

  INTERNET_PER_CONN_OPTION_LISTW list = {};
  list.dwSize = sizeof(list);
  list.pszConnection = nullptr;
  list.dwOptionCount = 3;
  list.pOptions = options;

  DWORD size = sizeof(list);
  ConnectionState state;
  if (!InternetQueryOptionW(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION,
                            &list, &size)) {
    return state;
  }
  state.ok = true;
  state.flags = options[0].Value.dwValue;
  // WinINet allocates these with GlobalAlloc; they are ours to free.
  if (options[1].Value.pszValue != nullptr) {
    state.server = options[1].Value.pszValue;
    GlobalFree(options[1].Value.pszValue);
  }
  if (options[2].Value.pszValue != nullptr) {
    state.bypass = options[2].Value.pszValue;
    GlobalFree(options[2].Value.pszValue);
  }
  return state;
}

inline bool SetForConnection(INTERNET_PER_CONN_OPTION_LISTW &list,
                             LPWSTR connection) {
  list.pszConnection = connection;
  return InternetSetOptionW(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION,
                            &list, sizeof(list)) != FALSE;
}

// The LAN connection, plus every dial-up/VPN entry, since each carries its own
// proxy settings.
inline bool ApplyToAllConnections(INTERNET_PER_CONN_OPTION_LISTW &list) {
  bool success = SetForConnection(list, nullptr);

  DWORD size = 0;
  DWORD count = 0;
  auto ret = RasEnumEntriesW(nullptr, nullptr, nullptr, &size, &count);
  if (ret == ERROR_BUFFER_TOO_SMALL && count > 0) {
    std::vector<RASENTRYNAMEW> entries(count);
    for (auto &entry : entries) {
      entry.dwSize = sizeof(RASENTRYNAMEW);
    }
    ret = RasEnumEntriesW(nullptr, nullptr, entries.data(), &size, &count);
    if (ret == ERROR_SUCCESS) {
      for (DWORD i = 0; i < count; i++) {
        success = SetForConnection(list, entries[i].szEntryName) && success;
      }
    } else {
      success = false;
    }
  } else if (ret != ERROR_SUCCESS) {
    success = false;
  }
  return success;
}

inline bool NotifyChanged() {
  const bool changed = InternetSetOptionW(
      nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0) != FALSE;
  const bool refreshed =
      InternetSetOptionW(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0) !=
      FALSE;
  return changed && refreshed;
}

inline bool Apply(DWORD flags, std::wstring server, std::wstring bypass) {
  INTERNET_PER_CONN_OPTIONW options[3] = {};
  options[0].dwOption = INTERNET_PER_CONN_FLAGS;
  options[0].Value.dwValue = flags;
  options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
  options[1].Value.pszValue = server.data();
  options[2].dwOption = INTERNET_PER_CONN_PROXY_BYPASS;
  options[2].Value.pszValue = bypass.data();

  INTERNET_PER_CONN_OPTION_LISTW list = {};
  list.dwSize = sizeof(list);
  list.dwOptionCount = 3;
  list.pOptions = options;
  return ApplyToAllConnections(list) && NotifyChanged();
}

// ── The record ──────────────────────────────────────────────────────────────

struct Record {
  bool present = false;
  std::wstring server;       // the proxy we set
  ConnectionState previous;  // what it replaced
};

inline bool ReadString(HKEY key, const wchar_t *name, std::wstring &out) {
  DWORD type = 0;
  DWORD bytes = 0;
  if (RegQueryValueExW(key, name, nullptr, &type, nullptr, &bytes) !=
          ERROR_SUCCESS ||
      type != REG_SZ) {
    return false;
  }
  std::wstring value(bytes / sizeof(wchar_t), L'\0');
  if (RegQueryValueExW(key, name, nullptr, nullptr,
                       reinterpret_cast<LPBYTE>(value.data()),
                       &bytes) != ERROR_SUCCESS) {
    return false;
  }
  while (!value.empty() && value.back() == L'\0') value.pop_back();
  out = value;
  return true;
}

inline void WriteString(HKEY key, const wchar_t *name,
                        const std::wstring &value) {
  RegSetValueExW(key, name, 0, REG_SZ,
                 reinterpret_cast<const BYTE *>(value.c_str()),
                 static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
}

inline Record ReadRecord() {
  Record record;
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kRecordKey, 0, KEY_QUERY_VALUE, &key) !=
      ERROR_SUCCESS) {
    return record;
  }
  DWORD flags = 0;
  DWORD size = sizeof(flags);
  DWORD type = 0;
  const bool haveServer = ReadString(key, L"Server", record.server);
  const bool haveFlags =
      RegQueryValueExW(key, L"PrevFlags", nullptr, &type,
                       reinterpret_cast<LPBYTE>(&flags),
                       &size) == ERROR_SUCCESS &&
      type == REG_DWORD;
  ReadString(key, L"PrevServer", record.previous.server);
  ReadString(key, L"PrevBypass", record.previous.bypass);
  RegCloseKey(key);
  record.present = haveServer && haveFlags && !record.server.empty();
  record.previous.ok = record.present;
  record.previous.flags = flags;
  return record;
}

inline void WriteRecord(const std::wstring &server,
                        const ConnectionState &previous) {
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kRecordKey, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }
  WriteString(key, L"Server", server);
  const DWORD flags = previous.flags;
  RegSetValueExW(key, L"PrevFlags", 0, REG_DWORD,
                 reinterpret_cast<const BYTE *>(&flags), sizeof(flags));
  WriteString(key, L"PrevServer", previous.server);
  WriteString(key, L"PrevBypass", previous.bypass);
  RegCloseKey(key);
}

inline void DeleteRecord() { RegDeleteKeyW(HKEY_CURRENT_USER, kRecordKey); }

// ── What the app calls ──────────────────────────────────────────────────────

inline bool IsProxyOn(const ConnectionState &state) {
  return state.ok && (state.flags & PROXY_TYPE_PROXY) != 0;
}

// Points the system at 127.0.0.1:[port], remembering what was there first.
inline bool Set(int port, const std::wstring &bypass) {
  const std::wstring ours = OurServer(port);
  const ConnectionState current = QueryDefaultConnection();
  const Record record = ReadRecord();

  // What to put back later. If what is there now is already ours - a second
  // start without a stop, or a crash - it is not the user's setting, and
  // recording it would make "restore" restore our own proxy.
  ConnectionState previous;
  const bool currentIsOurs =
      IsProxyOn(current) &&
      (current.server == ours ||
       (record.present && current.server == record.server));
  if (!currentIsOurs && current.ok) {
    previous = current;
  } else if (record.present) {
    previous = record.previous;
  } else {
    previous.flags = kWindowsDefaultFlags;
  }

  // Exactly DIRECT|PROXY while we are on. WinINet tries auto-detect and a PAC
  // script before a manual proxy, so leaving either enabled lets a network's
  // WPAD answer route the browser around us. They are switched off only for
  // as long as we are on - Restore puts back whatever the user had.
  if (!Apply(PROXY_TYPE_DIRECT | PROXY_TYPE_PROXY, ours, bypass)) {
    return false;
  }
  WriteRecord(ours, previous);
  return true;
}

// Undoes Set - but only when the proxy in place is ours.
//
// [fallbackPort] recognises a proxy of ours with no record, as left by a version
// of the app that did not write one. Pass 0 when the port is not known, as the
// uninstaller's launcher does.
inline bool Restore(int fallbackPort) {
  const ConnectionState current = QueryDefaultConnection();
  const Record record = ReadRecord();

  const bool ours =
      IsProxyOn(current) &&
      ((record.present && current.server == record.server) ||
       (fallbackPort > 0 && current.server == OurServer(fallbackPort)));

  if (!ours) {
    // Someone else's proxy, or none at all. Leave it exactly as it is. A record
    // left behind means the setting was changed after we set it, so it no
    // longer describes anything.
    if (record.present) DeleteRecord();
    return true;
  }

  ConnectionState previous = record.present ? record.previous
                                            : ConnectionState{};
  if (!record.present) previous.flags = kWindowsDefaultFlags;

  const bool applied =
      Apply(previous.flags | PROXY_TYPE_DIRECT, previous.server,
            previous.bypass);
  if (applied) DeleteRecord();
  return applied;
}

}  // namespace system_proxy
