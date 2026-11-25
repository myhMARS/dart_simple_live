import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_core/simple_live_core.dart';

class Log {
  static LogFileWriter? logFileWriter;
  static void initWriter() {
    logFileWriter = LogFileWriter();
  }

  static Future<void> disposeWriter() async {
    final writer = logFileWriter;
    logFileWriter = null;
    await writer?.close();
  }

  static void writeLog(content, [Level level = Level.info]) {
    logFileWriter
        ?.write("[${level.name.toUpperCase()}] $_currentTime：$content");
  }

  static RxList<DebugLogModel> debugLogs = <DebugLogModel>[].obs;

  static void addDebugLog(String content, Color? color) {
    if (kReleaseMode) {
      return;
    }
    if (content.contains("请求响应")) {
      content = content.split("\n").join('\n💡 ');
    }
    try {
      debugLogs.insert(0, DebugLogModel(DateTime.now(), content, color: color));
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  static Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );

  static void d(String message, [bool writeFile = true]) {
    addDebugLog(message, Colors.orange);
    logger.d("${DateTime.now().toString()}\n$message");
    if (writeFile) {
      writeLog(message, Level.debug);
    }
  }

  static void i(String message, [bool writeFile = true]) {
    addDebugLog(message, Colors.blue);
    logger.i("${DateTime.now().toString()}\n$message");
    if (writeFile) {
      writeLog(message, Level.info);
    }
  }

  static void e(String message, StackTrace stackTrace,
      [bool writeFile = true]) {
    addDebugLog('$message\r\n\r\n$stackTrace', Colors.red);
    logger.e("${DateTime.now().toString()}\n$message", stackTrace: stackTrace);
    if (writeFile) {
      writeLog("$message\n$stackTrace", Level.error);
    }
  }

  static void w(String message, [bool writeFile = true]) {
    addDebugLog(message, Colors.pink);
    logger.w("${DateTime.now().toString()}\n$message");
    if (writeFile) {
      writeLog(message, Level.warning);
    }
  }

  static void logPrint(dynamic obj, [bool writeFile = true]) {
    addDebugLog(obj.toString(), Colors.red);
    if (writeFile) {
      writeLog(obj, Level.info);
    }
    //logger.e(obj.toString(), obj, obj?.stackTrace);
    if (kDebugMode) {
      print(obj);
    }
  }

  static String get _currentTime => Utils.timeFormat.format(DateTime.now());
}

class LogFileWriter {
  late String fileName;
  late final Future<void> _initFuture;
  final StringBuffer _pending = StringBuffer();
  Timer? _flushTimer;
  bool _closed = false;
  bool _initFailed = false;

  LogFileWriter() {
    var dt = DateFormat("yyyy-MM-dd HH-mm-ss").format(DateTime.now());
    fileName = "$dt.log";
    _initFuture = initFile();
    // 定时 flush，避免 IOSink 缓冲导致磁盘文件长时间为空。
    _flushTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(flush());
    });
  }

  IOSink? fileWriter;

  Future<void> get ready => _initFuture;

  Future<void> initFile() async {
    try {
      var supportDir = await getApplicationSupportDirectory();
      var logDir = Directory("${supportDir.path}/log");
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      var logFile = File("${logDir.path}/$fileName");
      fileWriter = logFile.openWrite(mode: FileMode.append, encoding: utf8);
      if (_pending.isNotEmpty) {
        fileWriter!.write(_pending.toString());
        _pending.clear();
      }
      writeSystemInfo();
    } catch (e) {
      _initFailed = true;
      debugPrint("LogFileWriter init failed: $e");
    }
  }

  void write(String content) {
    if (_closed || _initFailed) {
      return;
    }
    final line = HttpLogSanitizer.redactText("$content\r\n");
    final sink = fileWriter;
    if (sink == null) {
      // 文件还没打开时先缓存，避免启动阶段日志丢失。
      _pending.write(line);
      return;
    }
    sink.write(line);
  }

  Future<void> flush() async {
    if (_closed) {
      return;
    }
    await _initFuture;
    final sink = fileWriter;
    if (sink == null) {
      return;
    }
    try {
      await sink.flush();
    } catch (_) {}
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _flushTimer?.cancel();
    await _initFuture;
    final sink = fileWriter;
    fileWriter = null;
    if (sink == null) {
      return;
    }
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {}
  }

  void writeSystemInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    write("System Info:");
    write("Current Time: ${DateTime.now()}");
    write("Platform: ${Platform.operatingSystem}");
    write("Version: ${Platform.operatingSystemVersion}");
    write("Local: ${Platform.localeName}");
    write(
        "App Version: ${Utils.packageInfo.version}+${Utils.packageInfo.buildNumber}");
    if (Platform.isAndroid) {
      write((await deviceInfo.androidInfo).data.toString());
    } else if (Platform.isIOS) {
      write((await deviceInfo.iosInfo).data.toString());
    } else if (Platform.isLinux) {
      write((await deviceInfo.linuxInfo).data.toString());
    } else if (Platform.isMacOS) {
      write((await deviceInfo.macOsInfo).data.toString());
    } else if (Platform.isWindows) {
      write((await deviceInfo.windowsInfo).data.toString());
    }
    write("End System Info");
  }
}

class DebugLogModel {
  final String content;
  final DateTime datetime;
  final Color? color;
  DebugLogModel(this.datetime, this.content, {this.color});
}
