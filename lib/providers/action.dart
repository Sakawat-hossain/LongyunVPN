import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/update_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

// The business-logic notifiers are split by concern into part files under
// actions/ (they share this library's imports). Generated providers for all of
// them land in the single generated/action.g.dart below.
part 'generated/action.g.dart';
part 'actions/common_action.dart';
part 'actions/setup_action.dart';
part 'actions/backup_action.dart';
part 'actions/core_action.dart';
part 'actions/system_action.dart';
part 'actions/store_action.dart';
part 'actions/theme_action.dart';
part 'actions/proxies_action.dart';
part 'actions/profiles_action.dart';
