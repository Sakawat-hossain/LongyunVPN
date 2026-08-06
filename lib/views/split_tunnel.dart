import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Localization ─────────────────────────────────────────────────────────────
//
// Kept in-file (like the leak test) so the view needs no Flutter-Intl codegen
// pass. Keyed by language code; falls back to English.

class _Strings {
  final String title;
  final String menuDesc;
  final String intro;
  final String modeOff;
  final String modeExclude;
  final String modeInclude;
  final String modeOffDesc;
  final String modeExcludeDesc;
  final String modeIncludeDesc;
  final String appsHeader;
  final String add;
  final String cancel;
  final String addTitle;
  final String addHint;
  final String emptyList;
  final String footnote;

  const _Strings({
    required this.title,
    required this.menuDesc,
    required this.intro,
    required this.modeOff,
    required this.modeExclude,
    required this.modeInclude,
    required this.modeOffDesc,
    required this.modeExcludeDesc,
    required this.modeIncludeDesc,
    required this.appsHeader,
    required this.add,
    required this.cancel,
    required this.addTitle,
    required this.addHint,
    required this.emptyList,
    required this.footnote,
  });
}

const _en = _Strings(
  title: 'Split tunnel',
  menuDesc: 'Choose which apps use the VPN',
  intro:
      'Route specific apps around the VPN, or send only specific apps through '
      'it. Matches by process name and applies on desktop.',
  modeOff: 'Off',
  modeExclude: 'Exclude selected apps',
  modeInclude: 'Only selected apps',
  modeOffDesc: 'All traffic goes through the VPN.',
  modeExcludeDesc: 'Listed apps bypass the VPN; everything else is tunneled.',
  modeIncludeDesc: 'Only listed apps are tunneled; everything else goes direct.',
  appsHeader: 'Apps',
  add: 'Add',
  cancel: 'Cancel',
  addTitle: 'Add a process',
  addHint: 'Process name, e.g. chrome.exe',
  emptyList: 'No apps added yet.',
  footnote:
      'Enter the exact process/executable name the system reports (for example '
      '“chrome.exe” on Windows, “Telegram” on macOS/Linux).',
);

const _zh = _Strings(
  title: '分应用代理',
  menuDesc: '选择哪些应用走 VPN',
  intro: '让特定应用绕过 VPN，或仅让特定应用走 VPN。按进程名匹配，仅在桌面端生效。',
  modeOff: '关闭',
  modeExclude: '排除所选应用',
  modeInclude: '仅所选应用',
  modeOffDesc: '所有流量都走 VPN。',
  modeExcludeDesc: '列表中的应用绕过 VPN，其余流量走 VPN。',
  modeIncludeDesc: '仅列表中的应用走 VPN，其余流量直连。',
  appsHeader: '应用',
  add: '添加',
  cancel: '取消',
  addTitle: '添加进程',
  addHint: '进程名，例如 chrome.exe',
  emptyList: '尚未添加应用。',
  footnote: '请输入系统显示的准确进程/可执行文件名（例如 Windows 上的 “chrome.exe”，macOS/Linux 上的 “Telegram”）。',
);

const _ja = _Strings(
  title: 'アプリ別トンネル',
  menuDesc: 'どのアプリが VPN を使うか選択',
  intro: '特定のアプリを VPN から除外したり、特定のアプリだけを VPN 経由にできます。プロセス名で判定し、デスクトップで有効です。',
  modeOff: 'オフ',
  modeExclude: '選択したアプリを除外',
  modeInclude: '選択したアプリのみ',
  modeOffDesc: 'すべての通信が VPN を経由します。',
  modeExcludeDesc: '一覧のアプリは VPN を迂回し、その他は VPN 経由になります。',
  modeIncludeDesc: '一覧のアプリのみ VPN 経由になり、その他は直接接続します。',
  appsHeader: 'アプリ',
  add: '追加',
  cancel: 'キャンセル',
  addTitle: 'プロセスを追加',
  addHint: 'プロセス名（例：chrome.exe）',
  emptyList: 'まだアプリが追加されていません。',
  footnote: 'システムが表示する正確なプロセス／実行ファイル名を入力してください（例：Windows は「chrome.exe」、macOS/Linux は「Telegram」）。',
);

const _ru = _Strings(
  title: 'Раздельный туннель',
  menuDesc: 'Выберите, какие приложения используют VPN',
  intro:
      'Пропускайте отдельные приложения мимо VPN или направляйте через него '
      'только выбранные. Сопоставление по имени процесса, работает на десктопе.',
  modeOff: 'Выкл.',
  modeExclude: 'Исключить выбранные',
  modeInclude: 'Только выбранные',
  modeOffDesc: 'Весь трафик идёт через VPN.',
  modeExcludeDesc: 'Приложения из списка идут мимо VPN, остальное — через VPN.',
  modeIncludeDesc: 'Через VPN идут только приложения из списка, остальное — напрямую.',
  appsHeader: 'Приложения',
  add: 'Добавить',
  cancel: 'Отмена',
  addTitle: 'Добавить процесс',
  addHint: 'Имя процесса, напр. chrome.exe',
  emptyList: 'Приложения ещё не добавлены.',
  footnote:
      'Введите точное имя процесса/исполняемого файла, как его сообщает система '
      '(например, «chrome.exe» в Windows, «Telegram» в macOS/Linux).',
);

_Strings _stringsFor(BuildContext context) {
  switch (Localizations.localeOf(context).languageCode) {
    case 'zh':
      return _zh;
    case 'ja':
      return _ja;
    case 'ru':
      return _ru;
    default:
      return _en;
  }
}

/// Localized label/subtitle for the Tools menu entry.
String splitTunnelTitle(BuildContext context) => _stringsFor(context).title;

String splitTunnelMenuDesc(BuildContext context) =>
    _stringsFor(context).menuDesc;

// ── View ─────────────────────────────────────────────────────────────────────

class SplitTunnelView extends ConsumerWidget {
  const SplitTunnelView({super.key});

  void _setMode(WidgetRef ref, SplitTunnelMode mode) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.splitTunnel(mode: mode));
  }

  void _setList(WidgetRef ref, List<String> list) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.splitTunnel(processList: list));
  }

  Future<void> _addProcess(
    BuildContext context,
    WidgetRef ref,
    List<String> current,
  ) async {
    final s = _stringsFor(context);
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.addTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: s.addHint),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(s.add),
          ),
        ],
      ),
    );
    final name = value?.trim() ?? '';
    if (name.isEmpty || current.contains(name)) return;
    _setList(ref, [...current, name]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _stringsFor(context);
    final theme = Theme.of(context);
    final props = ref.watch(
      patchClashConfigProvider.select((state) => state.splitTunnel),
    );
    final mode = props.mode;
    final list = props.processList;

    return CommonScaffold(
      title: s.title,
      floatingActionButton: mode == SplitTunnelMode.off
          ? null
          : FloatingActionButton(
              onPressed: () => _addProcess(context, ref, list),
              child: const Icon(Icons.add),
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(s.intro, style: theme.textTheme.bodyMedium),
          ),
          _ModeTile(
            label: s.modeOff,
            description: s.modeOffDesc,
            selected: mode == SplitTunnelMode.off,
            onTap: () => _setMode(ref, SplitTunnelMode.off),
          ),
          _ModeTile(
            label: s.modeExclude,
            description: s.modeExcludeDesc,
            selected: mode == SplitTunnelMode.exclude,
            onTap: () => _setMode(ref, SplitTunnelMode.exclude),
          ),
          _ModeTile(
            label: s.modeInclude,
            description: s.modeIncludeDesc,
            selected: mode == SplitTunnelMode.include,
            onTap: () => _setMode(ref, SplitTunnelMode.include),
          ),
          if (mode != SplitTunnelMode.off) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                s.appsHeader,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  s.emptyList,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final name in list)
                ListTile(
                  leading: const Icon(Icons.terminal),
                  title: Text(name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _setList(
                      ref,
                      list.where((item) => item != name).toList(),
                    ),
                  ),
                ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              s.footnote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? theme.colorScheme.primary : null,
      ),
      title: Text(label),
      subtitle: Text(description),
      onTap: onTap,
    );
  }
}
