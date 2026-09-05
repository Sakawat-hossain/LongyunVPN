[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={{INSTALL_DIR_NAME}}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
WizardStyle=modern
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed={{ARCH}}
ArchitecturesInstallIn64BitMode={{ARCH}}

[Code]
var
  WebView2Page: TDownloadWizardPage;

procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  // Include both the new (LongyunCore / LongyunVPNHelperService) and legacy
  // (FlClashCore / FlClashHelperService) binary names so an upgrade from an old
  // install can still terminate a running old core and helper.
  Processes := ['LongyunVPN.exe', 'LongyunCore.exe', 'FlClashCore.exe', 'LongyunVPNHelperService.exe', 'FlClashHelperService.exe'];

  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

// Remove the Windows service registration. The app creates it with `sc create`
// when it first needs elevation, but nothing ever removed it, so uninstalling
// left a registered service pointing at a deleted binary — which then failed to
// start on every boot and could block a later reinstall from recreating it.
// `sc delete` on a service that isn't there just returns an error we ignore, so
// this is safe to run unconditionally. The legacy FlClash name is included so an
// upgrade from an old install cleans up too.
procedure UnregisterHelperServices;
var
  Services: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  Services := ['LongyunVPNHelperService', 'FlClashHelperService'];

  for i := 0 to GetArrayLength(Services)-1 do
  begin
    Exec('sc', 'stop ' + Services[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('sc', 'delete ' + Services[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

// The in-app browser (IP whitelist, checkout) is WebView2, which needs the
// Evergreen Runtime. Windows 11 ships it; plenty of Windows 10, LTSC and
// freshly imaged machines do not, and there the browser cannot start at all.
// Detect it from the registry (per-machine and per-user, plus the WOW6432
// view), so we can tell the user up front instead of letting them discover it
// when a payment page refuses to open.
function WebView2Installed(): Boolean;
var
  Value: String;
begin
  Result :=
    (RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Value) and (Value <> '')) or
    (RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Value) and (Value <> '')) or
    (RegQueryStringValue(HKCU, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Value) and (Value <> ''));
end;

// Inverted for use as a Tasks Check, which must be a parameterless function.
function WebView2Missing(): Boolean;
begin
  Result := not WebView2Installed();
end;

function InitializeSetup(): Boolean;
begin
  KillProcesses;
  // The old blocking message box is gone: setup now offers to fetch the
  // runtime instead of telling the user to go and find it themselves. A
  // message that names a URL and then does nothing about it is work handed
  // back to the person least equipped to do it.
  Result := True;
end;

procedure InitializeWizard;
begin
  WebView2Page := CreateDownloadPage(
    SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), nil);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID <> wpReady) or (not WizardIsTaskSelected('webview2')) then
    exit;
  // The Evergreen bootstrapper: ~2 MB, always current, and Microsoft's
  // supported way to redistribute the runtime.
  WebView2Page.Clear;
  WebView2Page.Add(
    'https://go.microsoft.com/fwlink/p/?LinkId=2124703',
    'MicrosoftEdgeWebview2Setup.exe', '');
  WebView2Page.Show;
  try
    try
      WebView2Page.Download;
    except
      // Never fail the install over this. People install a VPN precisely
      // because their connection is restricted, and go.microsoft.com is slow
      // or unreachable on some of the networks this app exists to get around.
      // The app itself works without the runtime - only in-app pages do not -
      // so say what happened and carry on.
      SuppressibleMsgBox(
        ExpandConstant('{cm:WebView2DownloadFailed}'), mbInformation, MB_OK, IDOK);
    end;
  finally
    WebView2Page.Hide;
  end;
end;

// True only when the bootstrapper actually arrived, so the [Run] entry is
// skipped when the download failed rather than trying to execute nothing.
function WebView2Downloaded(): Boolean;
begin
  Result := FileExists(ExpandConstant('{tmp}\MicrosoftEdgeWebview2Setup.exe'));
end;

// Runs after the install directory is settled but before files are copied, so
// the old service is gone and its binary unlocked by the time we overwrite it.
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  UnregisterHelperServices;
  KillProcesses;
  Result := '';
end;

function InitializeUninstall(): Boolean;
begin
  UnregisterHelperServices;
  KillProcesses;
  Result := True;
end;

[Languages]
{% for locale in LOCALES %}
{% if locale.lang == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% if locale.lang == 'hy' %}Name: "armenian"; MessagesFile: "compiler:Languages\\Armenian.isl"{% endif %}
{% if locale.lang == 'bg' %}Name: "bulgarian"; MessagesFile: "compiler:Languages\\Bulgarian.isl"{% endif %}
{% if locale.lang == 'ca' %}Name: "catalan"; MessagesFile: "compiler:Languages\\Catalan.isl"{% endif %}
{% if locale.lang == 'zh' %}
Name: "chineseSimplified"; MessagesFile: {% if locale.file %}{{ locale.file }}{% else %}"compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% endif %}
{% if locale.lang == 'co' %}Name: "corsican"; MessagesFile: "compiler:Languages\\Corsican.isl"{% endif %}
{% if locale.lang == 'cs' %}Name: "czech"; MessagesFile: "compiler:Languages\\Czech.isl"{% endif %}
{% if locale.lang == 'da' %}Name: "danish"; MessagesFile: "compiler:Languages\\Danish.isl"{% endif %}
{% if locale.lang == 'nl' %}Name: "dutch"; MessagesFile: "compiler:Languages\\Dutch.isl"{% endif %}
{% if locale.lang == 'fi' %}Name: "finnish"; MessagesFile: "compiler:Languages\\Finnish.isl"{% endif %}
{% if locale.lang == 'fr' %}Name: "french"; MessagesFile: "compiler:Languages\\French.isl"{% endif %}
{% if locale.lang == 'de' %}Name: "german"; MessagesFile: "compiler:Languages\\German.isl"{% endif %}
{% if locale.lang == 'he' %}Name: "hebrew"; MessagesFile: "compiler:Languages\\Hebrew.isl"{% endif %}
{% if locale.lang == 'is' %}Name: "icelandic"; MessagesFile: "compiler:Languages\\Icelandic.isl"{% endif %}
{% if locale.lang == 'it' %}Name: "italian"; MessagesFile: "compiler:Languages\\Italian.isl"{% endif %}
{% if locale.lang == 'ja' %}Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"{% endif %}
{% if locale.lang == 'no' %}Name: "norwegian"; MessagesFile: "compiler:Languages\\Norwegian.isl"{% endif %}
{% if locale.lang == 'pl' %}Name: "polish"; MessagesFile: "compiler:Languages\\Polish.isl"{% endif %}
{% if locale.lang == 'pt' %}Name: "portuguese"; MessagesFile: "compiler:Languages\\Portuguese.isl"{% endif %}
{% if locale.lang == 'ru' %}Name: "russian"; MessagesFile: "compiler:Languages\\Russian.isl"{% endif %}
{% if locale.lang == 'sk' %}Name: "slovak"; MessagesFile: "compiler:Languages\\Slovak.isl"{% endif %}
{% if locale.lang == 'sl' %}Name: "slovenian"; MessagesFile: "compiler:Languages\\Slovenian.isl"{% endif %}
{% if locale.lang == 'es' %}Name: "spanish"; MessagesFile: "compiler:Languages\\Spanish.isl"{% endif %}
{% if locale.lang == 'tr' %}Name: "turkish"; MessagesFile: "compiler:Languages\\Turkish.isl"{% endif %}
{% if locale.lang == 'uk' %}Name: "ukrainian"; MessagesFile: "compiler:Languages\\Ukrainian.isl"{% endif %}
{% endfor %}

[CustomMessages]
english.InstallWebView2=Install Microsoft Edge WebView2 Runtime (about 2 MB download)
english.PrerequisitesGroup=Missing components:
english.WebView2DownloadFailed=The WebView2 Runtime could not be downloaded. Setup will continue without it; in-app pages such as checkout will not open until it is installed from:%n%nhttps://developer.microsoft.com/microsoft-edge/webview2/
chineseSimplified.InstallWebView2=安装 Microsoft Edge WebView2 运行时（约 2 MB 下载）
chineseSimplified.PrerequisitesGroup=缺少的组件：
chineseSimplified.WebView2DownloadFailed=无法下载 WebView2 运行时。安装将继续，但结账等应用内页面将无法打开，直到从以下地址安装：%n%nhttps://developer.microsoft.com/microsoft-edge/webview2/

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}
; Offered only when the runtime is genuinely absent, so a machine that already
; has it never sees the option or the download.
Name: "webview2"; Description: "{cm:InstallWebView2}"; GroupDescription: "{cm:PrerequisitesGroup}"; Check: WebView2Missing
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
[Run]
; Runs before the app launches, and only when the download succeeded. /silent
; keeps it out of the user's way; the bootstrapper exits quickly and does
; nothing when a newer runtime turns out to be present already.
Filename: "{tmp}\\MicrosoftEdgeWebview2Setup.exe"; Parameters: "/silent /install"; StatusMsg: "{cm:InstallWebView2}"; Flags: waituntilterminated; Tasks: webview2; Check: WebView2Downloaded
; Interactive install: the usual "Launch LongyunVPN" tick box on the last page.
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: {% if PRIVILEGES_REQUIRED == 'admin' %}runascurrentuser{% endif %} nowait postinstall skipifsilent
; Silent install: the in-app updater runs setup with /SILENT, and postinstall
; entries are skipped in that mode, so without this the app would be closed by
; the installer and never come back. runasoriginaluser matters here - setup is
; elevated, and relaunching as the elevated user would leave the app running as
; admin and writing its data as admin.
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Flags: runasoriginaluser nowait; Check: WizardSilent
