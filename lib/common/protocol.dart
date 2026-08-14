import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

class Protocol {
  static Protocol? _instance;

  Protocol._internal();

  factory Protocol() {
    _instance ??= Protocol._internal();
    return _instance!;
  }

  void register(String scheme) {
    final String protocolRegKey = 'Software\\Classes\\$scheme';
    const RegistryValue protocolRegValue = RegistryValue.string(
      'URL Protocol',
      '',
    );
    const String protocolCmdRegKey = 'shell\\open\\command';
    final RegistryValue protocolCmdRegValue = RegistryValue.string(
      '',
      '"${Platform.resolvedExecutable}" "%1"',
    );
    // Both keys own a native HKEY and have to be closed, including when
    // createValue throws — nothing released them before, so every registration
    // leaked two handles for the life of the process.
    final regKey = Registry.currentUser.createKey(protocolRegKey);
    try {
      regKey.createValue(protocolRegValue);
      final commandKey = regKey.createKey(protocolCmdRegKey);
      try {
        commandKey.createValue(protocolCmdRegValue);
      } finally {
        commandKey.close();
      }
    } finally {
      regKey.close();
    }
  }
}

final protocol = Protocol();
