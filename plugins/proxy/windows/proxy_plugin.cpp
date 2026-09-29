#include "proxy_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <string>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>

// Setting, recognising and restoring the system proxy lives in one place, shared
// with the app's launcher so the uninstaller applies exactly the same rules.
#include "system_proxy.h"

namespace
{

std::wstring Utf8ToWide(const std::string& value)
{
  if (value.empty())
  {
    return {};
  }
  const int size = MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0)
  {
    return std::wstring(value.begin(), value.end());
  }
  std::wstring result(size, L'\0');
  MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
      result.data(), size);
  return result;
}

std::wstring BuildBypassList(const flutter::EncodableList& bypassDomain)
{
  std::wstring bypassList;
  for (const auto& domain : bypassDomain) {
    const auto* value = std::get_if<std::string>(&domain);
    if (value == nullptr)
    {
      continue;
    }
    if (!bypassList.empty()) {
       bypassList += L";";
    }
    bypassList += Utf8ToWide(*value);
  }
  return bypassList;
}

}  // namespace

namespace proxy
{

  // static
  void ProxyPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "proxy",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<ProxyPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result)
        {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  ProxyPlugin::ProxyPlugin() {}

  ProxyPlugin::~ProxyPlugin() {}

  void ProxyPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (method_call.method_name().compare("StopProxy") == 0)
    {
      // The port is optional: it recognises a proxy of ours left by a version
      // that kept no record. Without it only a recorded proxy is undone.
      int port = 0;
      if (const auto *arguments =
              std::get_if<flutter::EncodableMap>(method_call.arguments()))
      {
        auto portIt = arguments->find(flutter::EncodableValue("port"));
        if (portIt != arguments->end())
        {
          if (const auto *value = std::get_if<int>(&portIt->second))
          {
            port = *value;
          }
        }
      }
      result->Success(system_proxy::Restore(port));
    }
    else if (method_call.method_name().compare("StartProxy") == 0)
    {
      auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments == nullptr)
      {
        result->Error("bad_args", "StartProxy requires argument map");
        return;
      }
      auto portIt = arguments->find(flutter::EncodableValue("port"));
      auto bypassDomainIt = arguments->find(flutter::EncodableValue("bypassDomain"));
      if (portIt == arguments->end() || bypassDomainIt == arguments->end())
      {
        result->Error("bad_args", "StartProxy requires port and bypassDomain");
        return;
      }
      auto *port = std::get_if<int>(&portIt->second);
      auto *bypassDomain = std::get_if<flutter::EncodableList>(&bypassDomainIt->second);
      if (port == nullptr || bypassDomain == nullptr)
      {
        result->Error("bad_args", "StartProxy argument types are invalid");
        return;
      }
      result->Success(
          system_proxy::Set(*port, BuildBypassList(*bypassDomain)));
    }
    else
    {
      result->NotImplemented();
    }
  }
} // namespace proxy
