// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ja';

  static String m0(amount) => "残り ${amount}";

  static String m1(done, total) => "チェック中…（${done}/${total}）";

  static String m2(count) => "${count}日前";

  static String m3(label) => "選択された${label}を削除してもよろしいですか？";

  static String m4(label) => "現在の${label}を削除してもよろしいですか？";

  static String m5(server) => "直接 IP（${server}）— 解決不要";

  static String m6(cn) => "ハンドシェイク成功（証明書：${cn}）";

  static String m7(ms) => "プロキシ経由 ${ms} ミリ秒";

  static String m8(server) => "${server} のアドレスレコードが見つかりません";

  static String m9(ms) => "到達可能 — ${ms} ミリ秒";

  static String m10(label) => "${label}詳細";

  static String m11(domains) => "このメールドメインは使用できません。利用可能：${domains}";

  static String m12(label) => "${label}は空欄にできません";

  static String m13(label) => "現在の${label}は既に存在しています";

  static String m14(value) => "出口 IP：${value}";

  static String m15(date) => "有効期限：${date}";

  static String m16(error) => "ノードの読み込みに失敗しました：${error}";

  static String m17(count) => "${count}時間前";

  static String m18(target) => "${target} は無効なポリシーです";

  static String m19(proxyName) => "${proxyName} は無効なプロキシです";

  static String m20(providerName) => "${providerName} は無効なプロキシプロバイダーです";

  static String m21(subRule) => "${subRule} は無効なSUB_RULEです";

  static String m22(appName) =>
      "1. Open System Settings > Privacy & Security\n2. Choose Location Services\n3. Find and check ${appName} in the right list\n\nAfter completing the setup, return to the app and use it normally. Thank you for your cooperation.";

  static String m23(count) => "${count}分前";

  static String m24(count) => "${count}ヶ月前";

  static String m25(count) => "残り ${count} 日";

  static String m26(count) => "異常 ${count} 件";

  static String m27(count) => "正常 ${count} 件";

  static String m28(count) => "合計 ${count} 件";

  static String m29(label) => "まだ${label}はありません";

  static String m30(label) => "${label}は数字でなければなりません";

  static String m31(label) => "${label} は 1024 から 49151 の間でなければなりません";

  static String m32(count) => "${count} 項目が選択されています";

  static String m33(error) => "登録設定を読み込めませんでした：${error}";

  static String m34(label) => "${label}はURLである必要があります";

  static String m35(used, total) => "${total} 中 ${used} 使用";

  static String m36(count) => "${count}年前";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("について"),
    "accessControl": MessageLookupByLibrary.simpleMessage("アクセス制御"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリのみVPNを許可",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "アプリケーションのプロキシアクセスを設定",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリをVPNから除外",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage("アクセス制御設定"),
    "account": MessageLookupByLibrary.simpleMessage("アカウント"),
    "action": MessageLookupByLibrary.simpleMessage("アクション"),
    "action_mode": MessageLookupByLibrary.simpleMessage("モード切替"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "action_start": MessageLookupByLibrary.simpleMessage("開始/停止"),
    "action_tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("表示/非表示"),
    "add": MessageLookupByLibrary.simpleMessage("追加"),
    "addProfile": MessageLookupByLibrary.simpleMessage("プロファイルを追加"),
    "addProxies": MessageLookupByLibrary.simpleMessage("プロキシを追加"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループを追加"),
    "addProxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダーを追加"),
    "addRule": MessageLookupByLibrary.simpleMessage("ルールを追加"),
    "addSsid": MessageLookupByLibrary.simpleMessage("SSIDを追加"),
    "addedRules": MessageLookupByLibrary.simpleMessage("追加ルール"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage("追加パラメータ"),
    "address": MessageLookupByLibrary.simpleMessage("アドレス"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAVサーバーアドレス"),
    "addressTip": MessageLookupByLibrary.simpleMessage("有効なWebDAVアドレスを入力"),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("高度な設定"),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage("多様な設定を提供"),
    "adviceDnsExplanation": MessageLookupByLibrary.simpleMessage(
      "このサーバーのアドレスを解決できませんでした。これはほぼ常に、サーバーではなくご利用のネットワークまたは DNS の問題です。",
    ),
    "adviceDnsFix": MessageLookupByLibrary.simpleMessage(
      "ネットワーク接続を確認してから、サブスクリプションを更新してください。",
    ),
    "adviceHealthyExplanation": MessageLookupByLibrary.simpleMessage(
      "このノードは到達可能で、正常に通信できています。",
    ),
    "adviceHealthyFix": MessageLookupByLibrary.simpleMessage(
      "準備完了です — このノードを選択して接続してください。",
    ),
    "adviceHttpExplanation": MessageLookupByLibrary.simpleMessage(
      "このノードは接続できますが、経由してインターネットに到達できません。通常はそのノードの一時的なサーバー側ルーティングの問題です。",
    ),
    "adviceHttpFix": MessageLookupByLibrary.simpleMessage(
      "別のノードに切り替えてください。すべてのノードで続く場合は、サポートにお問い合わせください。",
    ),
    "adviceIncompleteExplanation": MessageLookupByLibrary.simpleMessage(
      "テストが完了しませんでした。",
    ),
    "adviceIncompleteFix": MessageLookupByLibrary.simpleMessage(
      "もう一度実行してください。",
    ),
    "adviceTcpExplanation": MessageLookupByLibrary.simpleMessage(
      "このサーバーはご利用のネットワークから応答しません。一時的に停止しているか、ISP/ファイアウォールによってブロックされている可能性があります。",
    ),
    "adviceTcpFix": MessageLookupByLibrary.simpleMessage(
      "別のノードに切り替えてください。多くのノードが失敗する場合は、ネットワークを確認するかサポートにお問い合わせください。",
    ),
    "adviceTlsExplanation": MessageLookupByLibrary.simpleMessage(
      "サーバーには到達できますが、セキュア（TLS/Reality）ハンドシェイクに失敗しました。サブスクリプション内のサーバーキーが古い可能性があります。",
    ),
    "adviceTlsFix": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションを更新してください。それでも失敗する場合は、ノードを切り替えるかサポートにお問い合わせください。",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("同意"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("アプリがVPNをバイパスすることを許可"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると一部アプリがVPNをバイパス",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("LANを許可"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("LAN経由でのプロキシアクセスを許可"),
    "alreadyHaveAccountSignIn": MessageLookupByLibrary.simpleMessage(
      "すでにアカウントをお持ちですか？サインイン",
    ),
    "amountLeft": m0,
    "app": MessageLookupByLibrary.simpleMessage("アプリ"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("アプリアクセス制御"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("システムDNSを追加"),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "設定にシステムDNSを強制的に追加します",
    ),
    "application": MessageLookupByLibrary.simpleMessage("アプリケーション"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage("アプリ関連設定を変更"),
    "authorized": MessageLookupByLibrary.simpleMessage("許可済み"),
    "auto": MessageLookupByLibrary.simpleMessage("自動"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("自動更新チェック"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "起動時に更新を自動チェック",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("接続を自動閉じる"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "ノード変更後に接続を自動閉じる",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("自動起動"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("システムの自動起動に従う"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自動実行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("アプリ起動時に自動実行"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("オートセットシステムDNS"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔（分）"),
    "backup": MessageLookupByLibrary.simpleMessage("バックアップ"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage("バックアップと復元"),
    "backupAndRestoreDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAVまたはファイルを介してデータを同期する",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("バックアップ成功"),
    "balance": MessageLookupByLibrary.simpleMessage("残高"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("基本設定"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("基本設定をグローバルに変更"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("基本情報"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("基本戦略"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "To ensure background operation, please disable battery optimization for this app. Tap to go to settings.",
    ),
    "batteryOptimizationStatusTip": MessageLookupByLibrary.simpleMessage(
      "システムの影響により、この状態は必ずしも正確とは限りません。",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("バインド"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("ブラックリストモード"),
    "buy": MessageLookupByLibrary.simpleMessage("購入"),
    "buyPremium": MessageLookupByLibrary.simpleMessage("プレミアムを購入"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("バイパスドメイン"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage("システムプロキシ有効時のみ適用"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "キャッシュが破損しています。クリアしますか？",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("全選択解除"),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("更新を確認"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("アプリは最新版です"),
    "checkingProgress": m1,
    "checkout": MessageLookupByLibrary.simpleMessage("お支払い"),
    "clearData": MessageLookupByLibrary.simpleMessage("データを消去"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("クリップボードにエクスポート"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("クリップボードからインポート"),
    "color": MessageLookupByLibrary.simpleMessage("カラー"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("カラースキーム"),
    "columns": MessageLookupByLibrary.simpleMessage("列"),
    "compatible": MessageLookupByLibrary.simpleMessage("互換モード"),
    "completePaymentInBrowser": MessageLookupByLibrary.simpleMessage(
      "ブラウザで支払いを完了し、「支払い済み」をタップしてください。",
    ),
    "completed": MessageLookupByLibrary.simpleMessage("完了"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "設定内にデータが検出されました",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("確認"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "すべてのデータをクリアしてもよろしいですか？",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループを削除してもよろしいですか？",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "現在のウィンドウを閉じてもよろしいですか？",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "コアを強制的にクラッシュさせてもよろしいですか？",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "確認後、既存のデータは上書きされます",
    ),
    "confirmPassword": MessageLookupByLibrary.simpleMessage("パスワード（確認）"),
    "connected": MessageLookupByLibrary.simpleMessage("接続済み"),
    "connecting": MessageLookupByLibrary.simpleMessage("接続中..."),
    "connection": MessageLookupByLibrary.simpleMessage("接続"),
    "connections": MessageLookupByLibrary.simpleMessage("接続"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("現在の接続データを表示"),
    "connectivity": MessageLookupByLibrary.simpleMessage("接続性："),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage("内容は空にできません"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("コンテンツテーマ"),
    "continueToPayment": MessageLookupByLibrary.simpleMessage("支払いに進む"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "グローバル追加ルールを制御",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("コピー"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("環境変数をコピー"),
    "copyLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "copyReport": MessageLookupByLibrary.simpleMessage("レポートをコピー"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("コピー成功"),
    "core": MessageLookupByLibrary.simpleMessage("コア"),
    "coreStatus": MessageLookupByLibrary.simpleMessage("コアステータス"),
    "country": MessageLookupByLibrary.simpleMessage("国"),
    "couponCodeOptional": MessageLookupByLibrary.simpleMessage("クーポンコード（任意）"),
    "crashTest": MessageLookupByLibrary.simpleMessage("クラッシュテスト"),
    "crashlytics": MessageLookupByLibrary.simpleMessage("クラッシュ分析"),
    "crashlyticsTip": MessageLookupByLibrary.simpleMessage(
      "有効にすると、アプリがクラッシュした際に機密情報を含まないクラッシュログを自動的にアップロードします",
    ),
    "create": MessageLookupByLibrary.simpleMessage("作成"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Create Profile"),
    "creationTime": MessageLookupByLibrary.simpleMessage("作成時間"),
    "currentPlan": MessageLookupByLibrary.simpleMessage("現在のプラン"),
    "currentVersion": MessageLookupByLibrary.simpleMessage("現在のバージョン"),
    "custom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "cut": MessageLookupByLibrary.simpleMessage("切り取り"),
    "dark": MessageLookupByLibrary.simpleMessage("ダーク"),
    "dashboard": MessageLookupByLibrary.simpleMessage("ダッシュボード"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "データの変更が検出されました。保存しますか？",
    ),
    "dataCollectionContent": MessageLookupByLibrary.simpleMessage(
      "本アプリはFirebase Crashlyticsを使用してクラッシュ情報を収集し、アプリの安定性を向上させます。\n収集されるデータにはデバイス情報とクラッシュ詳細が含まれますが、個人の機密データは含まれません。\n設定でこの機能を無効にすることができます。",
    ),
    "dataCollectionTip": MessageLookupByLibrary.simpleMessage("データ収集説明"),
    "dataLabel": MessageLookupByLibrary.simpleMessage("通信量"),
    "daysAgo": m2,
    "daysLeftLabel": MessageLookupByLibrary.simpleMessage("日"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("デフォルトネームサーバー"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "DNSサーバーの解決用",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("デフォルト"),
    "delay": MessageLookupByLibrary.simpleMessage("遅延"),
    "delayTest": MessageLookupByLibrary.simpleMessage("遅延テスト"),
    "delete": MessageLookupByLibrary.simpleMessage("削除"),
    "deleteMultipTip": m3,
    "deleteTip": m4,
    "desc": MessageLookupByLibrary.simpleMessage(
      "ClashMetaベースのマルチプラットフォームプロキシクライアント。シンプルで使いやすく、オープンソースで広告なし。",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("宛先"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage("宛先地理情報"),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("宛先IP ASN"),
    "detailDirectIp": m5,
    "detailHandshakeOk": MessageLookupByLibrary.simpleMessage("ハンドシェイク成功"),
    "detailHandshakeOkCert": m6,
    "detailMsViaProxy": m7,
    "detailNoAddressRecords": m8,
    "detailNoHostPort": MessageLookupByLibrary.simpleMessage("ホスト:ポートがありません"),
    "detailNoResponseProxy": MessageLookupByLibrary.simpleMessage(
      "プロキシ経由で応答なし",
    ),
    "detailNoServerAddress": MessageLookupByLibrary.simpleMessage(
      "サーバーアドレスなし（プロバイダー型）",
    ),
    "detailReachableMs": m9,
    "detailSkippedFastPing": MessageLookupByLibrary.simpleMessage(
      "スキップ（高速 Ping）",
    ),
    "detailTlsSkippedNoTcp": MessageLookupByLibrary.simpleMessage(
      "スキップ — サーバーに接続できませんでした",
    ),
    "details": m10,
    "detectionTip": MessageLookupByLibrary.simpleMessage("サードパーティAPIに依存（参考値）"),
    "developerMode": MessageLookupByLibrary.simpleMessage("デベロッパーモード"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "デベロッパーモードが有効になりました。",
    ),
    "devices": MessageLookupByLibrary.simpleMessage("デバイス"),
    "diagnostics": MessageLookupByLibrary.simpleMessage("診断"),
    "diagnosticsDesc": MessageLookupByLibrary.simpleMessage(
      "ノードごとの TCP・DNS・プロキシ遅延テスト",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("ダイレクト"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("UDPを無効化"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("免責事項"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは学習交流や科学研究などの非営利目的でのみ使用されます。商用利用は厳禁です。いかなる商用活動も本ソフトウェアとは無関係です。",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("切断済み"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("新バージョンを発見"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS関連設定の更新"),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNSハイジャッキング"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNSモード"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage("通過させますか？"),
    "domain": MessageLookupByLibrary.simpleMessage("ドメイン"),
    "download": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "downloadingUpdate": MessageLookupByLibrary.simpleMessage("更新をダウンロード中…"),
    "edit": MessageLookupByLibrary.simpleMessage("編集"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage("グローバルルールを編集"),
    "editProxy": MessageLookupByLibrary.simpleMessage("プロキシを編集"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループを編集"),
    "editRule": MessageLookupByLibrary.simpleMessage("ルールを編集"),
    "editSsid": MessageLookupByLibrary.simpleMessage("SSIDを編集"),
    "email": MessageLookupByLibrary.simpleMessage("メールアドレス"),
    "emailDomainNotAllowed": m11,
    "emailInvalid": MessageLookupByLibrary.simpleMessage(
      "有効なメールアドレスを入力してください。",
    ),
    "emailRequired": MessageLookupByLibrary.simpleMessage("メールアドレスを入力してください。"),
    "emptyTip": m12,
    "en": MessageLookupByLibrary.simpleMessage("英語"),
    "entries": MessageLookupByLibrary.simpleMessage(" エントリ"),
    "exclude": MessageLookupByLibrary.simpleMessage("最近のタスクから非表示"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "アプリがバックグラウンド時に最近のタスクから非表示",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage("除外プロキシフィルター"),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Exclude SSIDs"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "When connected to an excluded SSID Wi-Fi, the app running state will be automatically switched.",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("除外タイプ"),
    "existsTip": m13,
    "exit": MessageLookupByLibrary.simpleMessage("終了"),
    "exitIpChecking": MessageLookupByLibrary.simpleMessage("実際の出口 IP を確認中…"),
    "exitIpUnavailable": MessageLookupByLibrary.simpleMessage(
      "出口 IP を取得できません — 現在のノードがインターネットに到達できません",
    ),
    "exitIpValue": m14,
    "expand": MessageLookupByLibrary.simpleMessage("標準"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("期待されるステータス"),
    "expires": MessageLookupByLibrary.simpleMessage("有効期限"),
    "expiresDate": m15,
    "exportFile": MessageLookupByLibrary.simpleMessage("ファイルをエクスポート"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("ログをエクスポート"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("エクスポート成功"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("エクスプレッシブ"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部コントローラー"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとClashコアをポート9090で制御可能",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("外部取得"),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部リンク"),
    "failedToReadNodes": m16,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fakeipフィルター"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fakeip範囲"),
    "fallback": MessageLookupByLibrary.simpleMessage("フォールバック"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("通常はオフショアDNSを使用"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("フォールバックフィルター"),
    "fastTcpPing": MessageLookupByLibrary.simpleMessage(
      "高速 TCP Ping（端末 → ノード）",
    ),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("ハイファイデリティー"),
    "file": MessageLookupByLibrary.simpleMessage("ファイル"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("プロファイルを直接アップロード"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "ファイルが変更されました。保存しますか？",
    ),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("プロセス検出"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとパフォーマンスが若干低下します",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("フォントファミリー"),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "コアを強制再起動してもよろしいですか？",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("フルーツサラダ"),
    "general": MessageLookupByLibrary.simpleMessage("一般"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo低メモリモード"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとGeo低メモリローダーを使用",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIPコード"),
    "getAPlan": MessageLookupByLibrary.simpleMessage("プランを購入"),
    "global": MessageLookupByLibrary.simpleMessage("グローバル"),
    "go": MessageLookupByLibrary.simpleMessage("移動"),
    "goDownload": MessageLookupByLibrary.simpleMessage("ダウンロードへ"),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage("スクリプト設定に移動"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("変更をキャッシュしますか？"),
    "hide": MessageLookupByLibrary.simpleMessage("非表示"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("リストから隠す"),
    "host": MessageLookupByLibrary.simpleMessage("ホスト"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("ホストを追加"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("ホットキー競合"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("ホットキー管理"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "キーボードでアプリを制御",
    ),
    "hoursAgo": m17,
    "icon": MessageLookupByLibrary.simpleMessage("アイコン"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("アイコン履歴"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("アイコンスタイル"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("アイコンURL"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignore Battery Optimization",
    ),
    "import": MessageLookupByLibrary.simpleMessage("インポート"),
    "importFile": MessageLookupByLibrary.simpleMessage("ファイルからインポート"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "importUrl": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage("すべてのプロキシを含める"),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "プロキシグループに含まれないすべてのプロキシをインポートします。下でさらにプロキシグループを追加できます",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "すべてのプロキシプロバイダーを含める",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "有効にすると、インポートされたプロキシプロバイダーを上書きします",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("長期有効"),
    "init": MessageLookupByLibrary.simpleMessage("初期化"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage("正しいホットキーを入力"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage("プロキシグループ名を入力"),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage("ルール内容を入力"),
    "installerLaunched": MessageLookupByLibrary.simpleMessage(
      "インストーラーを起動しました — 画面の指示に従って更新を完了してください。",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("インテリジェント選択"),
    "internet": MessageLookupByLibrary.simpleMessage("インターネット"),
    "interval": MessageLookupByLibrary.simpleMessage("インターバル"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("イントラネットIP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage("無効なバックアップファイル"),
    "invalidPolicy": m18,
    "invalidProxy": m19,
    "invalidProxyProvider": m20,
    "invalidSubRule": m21,
    "invitationCode": MessageLookupByLibrary.simpleMessage("招待コード"),
    "invitationCodeOptional": MessageLookupByLibrary.simpleMessage("招待コード（任意）"),
    "invitationCodeRequired": MessageLookupByLibrary.simpleMessage(
      "招待コードを入力してください。",
    ),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IPCIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("有効化するとIPv6トラフィックを受信可能"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage("IPv6インバウンドを許可"),
    "ivePaid": MessageLookupByLibrary.simpleMessage("支払い済み"),
    "ja": MessageLookupByLibrary.simpleMessage("日本語"),
    "justNow": MessageLookupByLibrary.simpleMessage("たった今"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCPキープアライブ間隔",
    ),
    "key": MessageLookupByLibrary.simpleMessage("キー"),
    "language": MessageLookupByLibrary.simpleMessage("言語"),
    "lastChecked": MessageLookupByLibrary.simpleMessage("最終チェック"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("最終更新"),
    "latestVersion": MessageLookupByLibrary.simpleMessage("最新バージョン"),
    "layout": MessageLookupByLibrary.simpleMessage("レイアウト"),
    "lifetime": MessageLookupByLibrary.simpleMessage("永久"),
    "lifetimePlan": MessageLookupByLibrary.simpleMessage("永久プラン"),
    "light": MessageLookupByLibrary.simpleMessage("ライト"),
    "list": MessageLookupByLibrary.simpleMessage("リスト"),
    "listen": MessageLookupByLibrary.simpleMessage("リスン"),
    "loadTest": MessageLookupByLibrary.simpleMessage("読み込みテスト"),
    "loading": MessageLookupByLibrary.simpleMessage("読み込み中..."),
    "local": MessageLookupByLibrary.simpleMessage("ローカル"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage("ローカルにデータをバックアップ"),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Location Permission",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "位置情報の権限が拒否されたため、現在の Wi-Fi 名を取得できません。システム設定で位置情報の権限を手動で有効にしてください。",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "According to system requirements, obtaining the Wi-Fi name requires you to grant location permission.",
    ),
    "locationPermissionGuide": m22,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Location Permission Required",
    ),
    "log": MessageLookupByLibrary.simpleMessage("ログ"),
    "logIn": MessageLookupByLibrary.simpleMessage("ログイン"),
    "logLevel": MessageLookupByLibrary.simpleMessage("ログレベル"),
    "logOut": MessageLookupByLibrary.simpleMessage("ログアウト"),
    "logcat": MessageLookupByLibrary.simpleMessage("ログキャット"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("無効化するとログエントリを非表示"),
    "logs": MessageLookupByLibrary.simpleMessage("ログ"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("ログキャプチャ記録"),
    "logsTest": MessageLookupByLibrary.simpleMessage("ログテスト"),
    "loopback": MessageLookupByLibrary.simpleMessage("ループバック解除ツール"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("UWPループバック解除用"),
    "loose": MessageLookupByLibrary.simpleMessage("疎"),
    "managePlan": MessageLookupByLibrary.simpleMessage("プランを管理"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("送信元IPをマッチング"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("最大失敗回数"),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("メモリ情報"),
    "messageTest": MessageLookupByLibrary.simpleMessage("メッセージテスト"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("これはメッセージです。"),
    "min": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("終了時に最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "システムの終了イベントを変更",
    ),
    "minutesAgo": m23,
    "mixedPort": MessageLookupByLibrary.simpleMessage("混合ポート"),
    "mode": MessageLookupByLibrary.simpleMessage("モード"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("モノクローム"),
    "monthsAgo": m24,
    "more": MessageLookupByLibrary.simpleMessage("詳細"),
    "nDaysLeft": m25,
    "nFailing": m26,
    "nHealthy": m27,
    "nTotal": m28,
    "name": MessageLookupByLibrary.simpleMessage("名前"),
    "nameserver": MessageLookupByLibrary.simpleMessage("ネームサーバー"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("ドメイン解決用"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("ネームサーバーポリシー"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "対応するネームサーバーポリシーを指定",
    ),
    "network": MessageLookupByLibrary.simpleMessage("ネットワーク"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("ネットワーク関連設定の変更"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("ネットワーク検出"),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "ネットワーク例外、接続を確認してもう一度お試しください",
    ),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("ネットワーク速度"),
    "networkType": MessageLookupByLibrary.simpleMessage("ネットワーク種別"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("ニュートラル"),
    "never": MessageLookupByLibrary.simpleMessage("なし"),
    "noAccountSignUp": MessageLookupByLibrary.simpleMessage(
      "アカウントをお持ちでないですか？登録",
    ),
    "noActivePlanChoose": MessageLookupByLibrary.simpleMessage(
      "有効なプランがありません — 下から選択して接続してください。",
    ),
    "noActiveProfileImport": MessageLookupByLibrary.simpleMessage(
      "有効なプロファイルがありません。まずサブスクリプションをインポートしてください。",
    ),
    "noActiveSubscription": MessageLookupByLibrary.simpleMessage(
      "有効なサブスクリプションがありません",
    ),
    "noActiveSubscriptionYet": MessageLookupByLibrary.simpleMessage(
      "有効なサブスクリプションがまだありません。しばらくしてからお試しください。",
    ),
    "noData": MessageLookupByLibrary.simpleMessage("データなし"),
    "noExpiry": MessageLookupByLibrary.simpleMessage("無期限"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("ホットキーなし"),
    "noInfo": MessageLookupByLibrary.simpleMessage("情報なし"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage("今後表示しない"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("ネットワークなし"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("ネットワークなしアプリ"),
    "noNodesAvailable": MessageLookupByLibrary.simpleMessage("利用可能なノードがありません"),
    "noNodesFound": MessageLookupByLibrary.simpleMessage(
      "有効なプロファイルにノードがありません。",
    ),
    "noNodesFoundTitle": MessageLookupByLibrary.simpleMessage("ノードが見つかりません"),
    "noPaymentMethods": MessageLookupByLibrary.simpleMessage(
      "利用可能な支払い方法がありません。",
    ),
    "noPlansAvailable": MessageLookupByLibrary.simpleMessage("利用可能なプランがありません。"),
    "noRecords": MessageLookupByLibrary.simpleMessage("履歴なし"),
    "noResolve": MessageLookupByLibrary.simpleMessage("IPを解決しない"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage("ホスト名を解決しない"),
    "noSubscription": MessageLookupByLibrary.simpleMessage("サブスクリプションなし"),
    "noSubscriptionServersMessage": MessageLookupByLibrary.simpleMessage(
      "有効な VPN プランがありません。\nプランを購入して VPN サーバーにアクセスしてください。",
    ),
    "nodeStatus": MessageLookupByLibrary.simpleMessage("ノード状態"),
    "none": MessageLookupByLibrary.simpleMessage("なし"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループは選択できません",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルがありません。追加してください",
    ),
    "nullTip": m29,
    "numberTip": m30,
    "offline": MessageLookupByLibrary.simpleMessage("オフライン"),
    "offlineNodes": MessageLookupByLibrary.simpleMessage("オフラインノード"),
    "onDemand": MessageLookupByLibrary.simpleMessage("On Demand"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "Configure the program running state for specific scenarios",
    ),
    "online": MessageLookupByLibrary.simpleMessage("オンライン"),
    "onlineNodes": MessageLookupByLibrary.simpleMessage("オンラインノード"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("アイコンのみ"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("プロキシのみ統計"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロキシトラフィックのみ統計",
    ),
    "optional": MessageLookupByLibrary.simpleMessage("オプション"),
    "options": MessageLookupByLibrary.simpleMessage("オプション"),
    "other": MessageLookupByLibrary.simpleMessage("その他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("その他の貢献者"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("アウトバウンドモード"),
    "override": MessageLookupByLibrary.simpleMessage("上書き"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("DNS上書き"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロファイルのDNS設定を上書き",
    ),
    "overrideMode": MessageLookupByLibrary.simpleMessage("上書きモード"),
    "overrideScript": MessageLookupByLibrary.simpleMessage("上書きスクリプト"),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "カスタムモード、プロキシグループとルールを完全にカスタマイズ可能",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("パレット"),
    "password": MessageLookupByLibrary.simpleMessage("パスワード"),
    "passwordRequired": MessageLookupByLibrary.simpleMessage("パスワードを入力してください。"),
    "passwordTooShort": MessageLookupByLibrary.simpleMessage(
      "パスワードは8文字以上で入力してください。",
    ),
    "passwordsDoNotMatch": MessageLookupByLibrary.simpleMessage(
      "パスワードが一致しません。",
    ),
    "paste": MessageLookupByLibrary.simpleMessage("貼り付け"),
    "paymentMethod": MessageLookupByLibrary.simpleMessage("支払い方法"),
    "periodHalfYearly": MessageLookupByLibrary.simpleMessage("半年"),
    "periodMonthly": MessageLookupByLibrary.simpleMessage("月額"),
    "periodOneTime": MessageLookupByLibrary.simpleMessage("買い切り"),
    "periodQuarterly": MessageLookupByLibrary.simpleMessage("3か月"),
    "periodThreeYears": MessageLookupByLibrary.simpleMessage("3年"),
    "periodTwoYears": MessageLookupByLibrary.simpleMessage("2年"),
    "periodYearly": MessageLookupByLibrary.simpleMessage("年額"),
    "planLabel": MessageLookupByLibrary.simpleMessage("プラン"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "WebDAVをバインドしてください",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "スクリプト名を入力してください",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "管理者パスワードを入力",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "有効なQRコードをアップロードしてください",
    ),
    "port": MessageLookupByLibrary.simpleMessage("ポート"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("別のポートを入力してください"),
    "portTip": m31,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("DOHのHTTP/3を優先使用"),
    "premium": MessageLookupByLibrary.simpleMessage("プレミアム"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Prerequisites"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("キーボードを押してください"),
    "preview": MessageLookupByLibrary.simpleMessage("プレビュー"),
    "process": MessageLookupByLibrary.simpleMessage("プロセス"),
    "profile": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("有効な間隔形式を入力してください"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("自動更新間隔を入力してください"),
    "profileFileNotFound": MessageLookupByLibrary.simpleMessage(
      "プロファイルファイルが見つかりません。",
    ),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "プロファイルが変更されました。自動更新を無効化しますか？",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル名を入力してください",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "有効なプロファイルURLを入力してください",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルURLを入力してください",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("プロファイル一覧"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("プロファイルの並び替え"),
    "project": MessageLookupByLibrary.simpleMessage("プロジェクト"),
    "providers": MessageLookupByLibrary.simpleMessage("プロバイダー"),
    "proxies": MessageLookupByLibrary.simpleMessage("サーバー"),
    "proxiesEmpty": MessageLookupByLibrary.simpleMessage("プロキシが空です"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("プロキシチェーン"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "選択されたプロキシに異常があることを検出しました",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("プロキシフィルター"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループ"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループが異常であることを検出しました",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage("プロキシグループが空です"),
    "proxyGroupNameDuplicate": MessageLookupByLibrary.simpleMessage(
      "プロキシグループ名が重複しています",
    ),
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "プロキシグループ名は空にできません",
    ),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("プロキシネームサーバー"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシノード解決用ドメイン",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("プロキシポート"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "選択されたプロキシプロバイダーに異常があることを検出しました",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダー"),
    "proxyProvidersEmpty": MessageLookupByLibrary.simpleMessage(
      "プロキシプロバイダーが空です",
    ),
    "proxyProvidersNotEmpty": MessageLookupByLibrary.simpleMessage(
      "プロキシプロバイダーは空にできません",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("プロキシタイプ"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("キャッシュの削除"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("純黒モード"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QRコード"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage("QRコードをスキャンしてプロファイルを取得"),
    "quickFill": MessageLookupByLibrary.simpleMessage("クイック入力"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("レインボー"),
    "recheckExitIp": MessageLookupByLibrary.simpleMessage("出口 IP を再確認"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redirポート"),
    "redo": MessageLookupByLibrary.simpleMessage("やり直す"),
    "refresh": MessageLookupByLibrary.simpleMessage("更新"),
    "refreshStatus": MessageLookupByLibrary.simpleMessage("状態を更新"),
    "refreshSubscriptionHint": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションを更新してください。",
    ),
    "refreshing": MessageLookupByLibrary.simpleMessage("更新中…"),
    "remote": MessageLookupByLibrary.simpleMessage("リモート"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAVにデータをバックアップ",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("リモート宛先"),
    "remove": MessageLookupByLibrary.simpleMessage("削除"),
    "rename": MessageLookupByLibrary.simpleMessage("リネーム"),
    "renew": MessageLookupByLibrary.simpleMessage("継続"),
    "renewNow": MessageLookupByLibrary.simpleMessage("今すぐ継続"),
    "renewUpgrade": MessageLookupByLibrary.simpleMessage("継続 / アップグレード"),
    "reportCopied": MessageLookupByLibrary.simpleMessage(
      "診断レポートをクリップボードにコピーしました",
    ),
    "request": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requests": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("最近のリクエスト記録を表示"),
    "reset": MessageLookupByLibrary.simpleMessage("リセット"),
    "resetData": MessageLookupByLibrary.simpleMessage("通信量をリセット"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "現在のページに変更があります。リセットしてもよろしいですか？",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage("リセットを確定"),
    "resetTraffic": MessageLookupByLibrary.simpleMessage("通信量をリセット"),
    "resources": MessageLookupByLibrary.simpleMessage("リソース"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("外部リソース関連情報"),
    "respectRules": MessageLookupByLibrary.simpleMessage("ルール尊重"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS接続がルールに従う（proxy-server-nameserverの設定が必要）",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("再起動"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage("コアを再起動してもよろしいですか？"),
    "restore": MessageLookupByLibrary.simpleMessage("復元"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("すべてのデータを復元する"),
    "restoreException": MessageLookupByLibrary.simpleMessage("復元例外"),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "ファイルを介してデータを復元する",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAVを介してデータを復元する",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage("設定ファイルのみを復元する"),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("復元ストラテジー"),
    "restoreStrategy_compatible": MessageLookupByLibrary.simpleMessage("互換"),
    "restoreStrategy_override": MessageLookupByLibrary.simpleMessage("上書き"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("復元に成功しました"),
    "retry": MessageLookupByLibrary.simpleMessage("再試行"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("ルートアドレス"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage("ルートアドレスを設定"),
    "routeMode": MessageLookupByLibrary.simpleMessage("ルートモード"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "プライベートルートをバイパス",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("設定を使用"),
    "ru": MessageLookupByLibrary.simpleMessage("ロシア語"),
    "rule": MessageLookupByLibrary.simpleMessage("ルール"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage("論理ルール AND"),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "完全なドメインをマッチング",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "ドメインキーワードをマッチング",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "ワイルドカードマッチング（*と?のみサポート）",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "ドメイン接尾辞をマッチング",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "DSCPマークをマッチング (tproxy udp inboundのみ)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "宛先ポート範囲をマッチング",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "IPの国コードをマッチング",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Match domains within Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンド名をマッチング",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドポートをマッチング",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドタイプをマッチング",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドユーザー名をマッチング（/で複数指定可）",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage("IPのASNをマッチング"),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "IPアドレス範囲をマッチング（IP-CIDR6はエイリアスです）",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "IPアドレス範囲をマッチング",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "IP接尾辞範囲をマッチング",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "すべてのリクエストにマッチ（条件なし）",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "TCPまたはUDPをマッチング",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage("論理ルール NOT"),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("論理ルール OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名でマッチング（Androidではパッケージ名）",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名正規表現でマッチング（Androidではパッケージ名）",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "フルプロセスパスでマッチング",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスパス正規表現でマッチング",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "ルールセットを参照。rule-providersの設定が必要",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPの国コードをマッチング",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPのASNをマッチング",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPアドレス範囲をマッチング",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IP接尾辞範囲をマッチング",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "送信元ポート範囲をマッチング",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "サブルールにマッチング。括弧の使用に注意",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Linux USER IDをマッチング",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("ルールが空です"),
    "ruleName": MessageLookupByLibrary.simpleMessage("ルール名"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("ルールプロバイダー"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("ルールセット"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("ルール対象"),
    "runFullTests": MessageLookupByLibrary.simpleMessage("完全テストを実行"),
    "runTest": MessageLookupByLibrary.simpleMessage("実行"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("変更を保存しますか？"),
    "script": MessageLookupByLibrary.simpleMessage("スクリプト"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "スクリプトモード、外部拡張スクリプトを使用し、ワンクリックで設定を上書きする機能を提供",
    ),
    "search": MessageLookupByLibrary.simpleMessage("検索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "selectAll": MessageLookupByLibrary.simpleMessage("すべて選択"),
    "selectProxies": MessageLookupByLibrary.simpleMessage("プロキシを選択"),
    "selectProxyProviders": MessageLookupByLibrary.simpleMessage(
      "プロキシプロバイダーを選択",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage("ルールセットを選択してください"),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "分流戦略を選択してください",
    ),
    "selectSubRule": MessageLookupByLibrary.simpleMessage("サブルールを選択してください"),
    "selected": MessageLookupByLibrary.simpleMessage("選択済み"),
    "selectedCountTitle": m32,
    "sendCode": MessageLookupByLibrary.simpleMessage("コードを送信"),
    "settings": MessageLookupByLibrary.simpleMessage("設定"),
    "show": MessageLookupByLibrary.simpleMessage("表示"),
    "shrink": MessageLookupByLibrary.simpleMessage("縮小"),
    "signIn": MessageLookupByLibrary.simpleMessage("サインイン"),
    "signUp": MessageLookupByLibrary.simpleMessage("登録"),
    "signupConfigError": m33,
    "silentLaunch": MessageLookupByLibrary.simpleMessage("バックグラウンド起動"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage("バックグラウンドで起動"),
    "size": MessageLookupByLibrary.simpleMessage("サイズ"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socksポート"),
    "sort": MessageLookupByLibrary.simpleMessage("並び替え"),
    "source": MessageLookupByLibrary.simpleMessage("ソース"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("送信元IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("特殊プロキシ"),
    "specialRules": MessageLookupByLibrary.simpleMessage("特殊ルール"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("速度統計"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("分流戦略"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "分流戦略は空にできません",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDs is empty"),
    "stackMode": MessageLookupByLibrary.simpleMessage("スタックモード"),
    "standard": MessageLookupByLibrary.simpleMessage("標準"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "標準モード、基本設定を上書きし、シンプルなルール追加機能を提供",
    ),
    "start": MessageLookupByLibrary.simpleMessage("開始"),
    "startVpn": MessageLookupByLibrary.simpleMessage("VPNを開始中..."),
    "status": MessageLookupByLibrary.simpleMessage("ステータス"),
    "statusActive": MessageLookupByLibrary.simpleMessage("有効"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("無効時はシステムDNSを使用"),
    "statusExpired": MessageLookupByLibrary.simpleMessage("期限切れ"),
    "statusExpiringSoon": MessageLookupByLibrary.simpleMessage("まもなく期限切れ"),
    "statusInactive": MessageLookupByLibrary.simpleMessage("無効"),
    "stepDnsLookup": MessageLookupByLibrary.simpleMessage("DNS 解決"),
    "stepHttpDelay": MessageLookupByLibrary.simpleMessage("HTTP 遅延（プロキシ経由）"),
    "stepTcpConnectivity": MessageLookupByLibrary.simpleMessage("TCP 接続"),
    "stepTlsHandshake": MessageLookupByLibrary.simpleMessage(
      "TLS / HTTPS ハンドシェイク",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("停止"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("VPNを停止中..."),
    "style": MessageLookupByLibrary.simpleMessage("スタイル"),
    "subRule": MessageLookupByLibrary.simpleMessage("サブルール"),
    "subRuleEmpty": MessageLookupByLibrary.simpleMessage("サブルールが空です"),
    "subRuleNotEmpty": MessageLookupByLibrary.simpleMessage("サブルールは空にできません"),
    "submit": MessageLookupByLibrary.simpleMessage("送信"),
    "subscriptionActive": MessageLookupByLibrary.simpleMessage("サブスクリプション有効"),
    "subscriptionActiveImported": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションが有効になり、プロファイルをインポートしました。",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("一時停止中..."),
    "sync": MessageLookupByLibrary.simpleMessage("同期"),
    "system": MessageLookupByLibrary.simpleMessage("システム"),
    "systemApp": MessageLookupByLibrary.simpleMessage("システムアプリ"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "HTTPプロキシをVpnServiceに接続",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("タブ"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("タブアニメーション"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage("モバイル表示でのみ有効"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("タップして許可"),
    "tapToTest": MessageLookupByLibrary.simpleMessage("▶ をタップしてテスト"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP並列処理"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("TCP並列処理を許可"),
    "testInterval": MessageLookupByLibrary.simpleMessage("テスト間隔"),
    "testUrl": MessageLookupByLibrary.simpleMessage("URLテスト"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("使用時にテスト"),
    "textScale": MessageLookupByLibrary.simpleMessage("テキストスケーリング"),
    "theme": MessageLookupByLibrary.simpleMessage("テーマ"),
    "themeColor": MessageLookupByLibrary.simpleMessage("テーマカラー"),
    "themeDesc": MessageLookupByLibrary.simpleMessage("ダークモードの設定、色の調整"),
    "themeMode": MessageLookupByLibrary.simpleMessage("テーマモード"),
    "tight": MessageLookupByLibrary.simpleMessage("密"),
    "time": MessageLookupByLibrary.simpleMessage("時間"),
    "timedOut": MessageLookupByLibrary.simpleMessage("タイムアウト"),
    "timeout": MessageLookupByLibrary.simpleMessage("タイムアウト"),
    "tip": MessageLookupByLibrary.simpleMessage("ヒント"),
    "toggle": MessageLookupByLibrary.simpleMessage("トグル"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("トーンスポット"),
    "tools": MessageLookupByLibrary.simpleMessage("ツール"),
    "totalNodes": MessageLookupByLibrary.simpleMessage("ノード総数"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxyポート"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("トラフィック使用量"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage("管理者モードでのみ有効"),
    "turnOff": MessageLookupByLibrary.simpleMessage("オフ"),
    "turnOn": MessageLookupByLibrary.simpleMessage("オン"),
    "undo": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("統一遅延"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "ハンドシェイクなどの余分な遅延を削除",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("不明"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage("不明なネットワークエラー"),
    "unknownNodes": MessageLookupByLibrary.simpleMessage("不明なノード"),
    "unnamed": MessageLookupByLibrary.simpleMessage("無題"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "updateDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "ダウンロードに失敗しました。リリースページを開きます。",
    ),
    "updateNow": MessageLookupByLibrary.simpleMessage("今すぐ更新"),
    "upload": MessageLookupByLibrary.simpleMessage("アップロード"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("URL経由でプロファイルを取得"),
    "urlTip": m34,
    "useHosts": MessageLookupByLibrary.simpleMessage("ホストを使用"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("システムホストを使用"),
    "usedOfTotal": m35,
    "value": MessageLookupByLibrary.simpleMessage("値"),
    "verdictCantPassTraffic": MessageLookupByLibrary.simpleMessage("通信できません"),
    "verdictDnsFailed": MessageLookupByLibrary.simpleMessage("名前解決に失敗"),
    "verdictHealthy": MessageLookupByLibrary.simpleMessage("正常"),
    "verdictIncomplete": MessageLookupByLibrary.simpleMessage("未完了"),
    "verdictNotTested": MessageLookupByLibrary.simpleMessage("未テスト"),
    "verdictServerNotResponding": MessageLookupByLibrary.simpleMessage(
      "サーバー応答なし",
    ),
    "verdictTesting": MessageLookupByLibrary.simpleMessage("テスト中…"),
    "verdictTlsFailed": MessageLookupByLibrary.simpleMessage("セキュアハンドシェイク失敗"),
    "verificationCode": MessageLookupByLibrary.simpleMessage("認証コード"),
    "verificationCodeRequired": MessageLookupByLibrary.simpleMessage(
      "認証コードを入力してください。",
    ),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("ビブラント"),
    "view": MessageLookupByLibrary.simpleMessage("表示"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN設定の変更が検出されました",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VpnService経由で全システムトラフィックをルーティング",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage("変更はVPN再起動後に有効"),
    "waitingForPayment": MessageLookupByLibrary.simpleMessage(
      "支払いを待っています。支払い後、下をタップして有効化してください。",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV設定"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("ホワイトリストモード"),
    "yearsAgo": m36,
    "zh_CN": MessageLookupByLibrary.simpleMessage("簡体字中国語"),
  };
}
