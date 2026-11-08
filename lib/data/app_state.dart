import 'dart:convert';
import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../core/utils.dart';
import 'attachment_store.dart';
import 'backup_service.dart';
import 'backup_types.dart';
import 'crypto_service.dart';
import 'local_store.dart';
import 'models/app_settings.dart';
import 'models/countdown_item.dart';
import 'models/file_item.dart';
import 'models/note.dart';
import 'models/password_entry.dart';
import 'models/todo_item.dart';

/// 可进入回收站的条目类型。
enum EntityType {
  password('密码本'),
  note('备忘录'),
  todo('待办'),
  countdown('倒数日'),
  file('文件库');

  const EntityType(this.label);

  final String label;
}

/// 回收站里的一条记录（来自不同模块）。
class TrashRecord {
  TrashRecord({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.deletedAt,
  });

  final EntityType type;
  final String id;
  final String title;
  final String subtitle;
  final DateTime deletedAt;
}

/// 应用全局状态：解锁、数据读写、增删改查、回收站、备份导入导出。
/// 所有数据在内存中是明文，落盘时敏感字段会被加密；锁屏后内存数据会被清空。
class AppState extends ChangeNotifier {
  AppState({LocalStore? store, AttachmentStore? attachments})
      : store = store ?? LocalStore.instance,
        attachments = attachments ?? AttachmentStore.instance;

  final LocalStore store;
  final AttachmentStore attachments;
  final CryptoService crypto = CryptoService.instance;
  final BackupService backup = BackupService.instance;

  static late AppState instance;

  AppSettings settings = AppSettings();

  List<PasswordEntry> passwords = <PasswordEntry>[];
  List<Note> notes = <Note>[];
  List<TodoItem> todos = <TodoItem>[];
  List<CountdownItem> countdowns = <CountdownItem>[];
  List<FileItem> files = <FileItem>[];

  bool _locked = true;
  bool _ready = false;
  SecretKey? _key;

  /// 解锁密码只保留在内存里（用于导出备份时重新派生备份密钥），锁屏即清除。
  String? _sessionPassword;
  String? get sessionPassword => _sessionPassword;

  DateTime _lastActivity = DateTime.now();
  Timer? _autoLockTimer;
  Timer? _saveTimer;
  bool _savePending = false;

  bool get locked => _locked;
  bool get unlocked => _key != null;
  bool get ready => _ready;

  /// 是否还没有设置解锁密码（首次启动）。
  bool get needsSetup => !settings.hasPassword;

  /// 当前环境是否支持本地文件（网页预览不支持）。
  bool get supportsFiles => attachments.supported;

  /// 网页预览模式，界面上会给出相应提示。
  bool get isPreviewMode => !attachments.supported;

  /// 启动时加载设置与本地库。
  /// [storagePath] 仅供测试指定临时目录。
  Future<void> bootstrap({String? storagePath}) async {
    await store.init(path: storagePath);
    try {
      await attachments.init();
    } catch (error) {
      // 附件目录初始化失败时仍允许使用文字功能，只是文件库不可用
      debugPrint('附件目录初始化失败：$error');
    }
    settings = AppSettings.fromMap(store.readMap(LocalStore.keySettings));
    _ready = true;
    _locked = true;
    _startAutoLockWatcher();
    notifyListeners();
  }

  // ---------------------------------------------------------------- 解锁

  /// 首次启动：设置解锁密码并初始化空数据。
  Future<void> setupPassword(String password) async {
    final salt = CryptoService.randomBytes(CryptoService.saltLength);
    final key = await crypto.deriveKey(password, salt);
    final verifier = await crypto.createVerifier(key);

    settings = settings.copyWith(
      passwordSalt: base64Encode(salt),
      passwordCheck: verifier,
      hasPassword: true,
    );
    _key = key;
    passwords = [];
    notes = [];
    todos = [];
    countdowns = [];
    files = [];
    _locked = false;
    _sessionPassword = password;
    await _persist();
    _touch();
    _startAutoLockWatcher();
    notifyListeners();
  }

  /// 用解锁密码打开本子。密码错误返回 false。
  Future<bool> unlock(String password) async {
    final saltBase64 = settings.passwordSalt;
    if (saltBase64 == null) return false;
    final salt = Uint8List.fromList(base64Decode(saltBase64));
    final key = await crypto.deriveKey(password, salt);
    if (!await crypto.verifyKey(key, settings.passwordCheck)) {
      return false;
    }
    _key = key;
    await _loadAll(key);
    _locked = false;
    _sessionPassword = password;
    _touch();
    _startAutoLockWatcher();
    notifyListeners();
    return true;
  }

  /// 校验密码（用于清除数据、修改密码前的确认）。
  Future<bool> checkPassword(String password) async {
    final saltBase64 = settings.passwordSalt;
    if (saltBase64 == null) return false;
    final salt = Uint8List.fromList(base64Decode(saltBase64));
    final key = await crypto.deriveKey(password, salt);
    return crypto.verifyKey(key, settings.passwordCheck);
  }

  /// 修改解锁密码：重新生成盐，并用新密钥重新加密所有敏感字段。
  Future<void> changePassword(String newPassword) async {
    final salt = CryptoService.randomBytes(CryptoService.saltLength);
    final key = await crypto.deriveKey(newPassword, salt);
    final verifier = await crypto.createVerifier(key);
    settings = settings.copyWith(
      passwordSalt: base64Encode(salt),
      passwordCheck: verifier,
      hasPassword: true,
    );
    _key = key;
    _sessionPassword = newPassword;
    await _persist();
    notifyListeners();
  }

  /// 立即锁屏：先把数据写盘，再清空内存中的明文。
  Future<void> lockNow() async {
    if (_locked) return;
    _saveTimer?.cancel();
    await _persist();
    _key = null;
    _sessionPassword = null;
    passwords = [];
    notes = [];
    todos = [];
    countdowns = [];
    files = [];
    _locked = true;
    notifyListeners();
  }

  /// 记录用户活跃时间，供自动锁屏计时使用。
  void touch() => _touch();

  void _touch() => _lastActivity = DateTime.now();

  void _startAutoLockWatcher() {
    _autoLockTimer?.cancel();
    // 关闭自动锁屏时不保留计时器，省电也避免后台空转
    if (settings.autoLockMinutes <= 0) return;
    _autoLockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!unlocked) return;
      final minutes = settings.autoLockMinutes;
      if (minutes <= 0) return;
      if (DateTime.now().difference(_lastActivity) >= Duration(minutes: minutes)) {
        lockNow();
      }
    });
  }

  // ---------------------------------------------------------------- 设置

  void setThemeModeIndex(int index) {
    settings = settings.copyWith(themeModeIndex: index);
    _persistSettings();
    notifyListeners();
  }

  void setFontScale(double scale) {
    settings = settings.copyWith(fontScale: scale.clamp(0.85, 1.35));
    _persistSettings();
    notifyListeners();
  }

  void setAutoLockMinutes(int minutes) {
    settings = settings.copyWith(autoLockMinutes: minutes);
    _persistSettings();
    _startAutoLockWatcher(); // 立刻按新的时长重新计时
    notifyListeners();
  }

  Future<void> _persistSettings() async {
    if (store.isReady) {
      await store.writeMap(LocalStore.keySettings, settings.toMap());
    }
  }

  // ---------------------------------------------------------------- 数据读写

  Future<void> _loadAll(SecretKey key) async {
    passwords = [];
    for (final map in store.readList(LocalStore.keyPasswords)) {
      try {
        passwords.add(PasswordEntry(
          id: map['id'].toString(),
          title: (map['title'] ?? '').toString(),
          username: await crypto.decryptString(key, (map['username'] ?? '').toString()),
          password: await crypto.decryptString(key, (map['password'] ?? '').toString()),
          notes: await crypto.decryptString(key, (map['notes'] ?? '').toString()),
          tags: _stringList(map['tags']),
          pinned: map['pinned'] == true,
          createdAt: _date(map['createdAt']),
          updatedAt: _date(map['updatedAt']),
          deletedAt: map['deletedAt'] == null ? null : _date(map['deletedAt']),
        ));
      } catch (error) {
        debugPrint('密码本条目读取失败：$error');
      }
    }

    notes = [];
    for (final map in store.readList(LocalStore.keyNotes)) {
      try {
        final encrypted = map['encrypted'] == true;
        final rawContent = (map['content'] ?? '').toString();
        notes.add(Note(
          id: map['id'].toString(),
          title: (map['title'] ?? '').toString(),
          content: encrypted
              ? await crypto.decryptString(key, rawContent)
              : rawContent,
          tags: _stringList(map['tags']),
          images: _stringList(map['images']),
          pinned: map['pinned'] == true,
          encrypted: encrypted,
          createdAt: _date(map['createdAt']),
          updatedAt: _date(map['updatedAt']),
          deletedAt: map['deletedAt'] == null ? null : _date(map['deletedAt']),
        ));
      } catch (error) {
        debugPrint('备忘录读取失败：$error');
      }
    }

    todos = [];
    for (final map in store.readList(LocalStore.keyTodos)) {
      try {
        todos.add(TodoItem.fromPlainMap(map));
      } catch (error) {
        debugPrint('待办读取失败：$error');
      }
    }

    countdowns = [];
    for (final map in store.readList(LocalStore.keyCountdowns)) {
      try {
        countdowns.add(CountdownItem.fromPlainMap(map));
      } catch (error) {
        debugPrint('倒数日读取失败：$error');
      }
    }

    files = [];
    for (final map in store.readList(LocalStore.keyFiles)) {
      try {
        files.add(FileItem.fromPlainMap(map));
      } catch (error) {
        debugPrint('文件库读取失败：$error');
      }
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  DateTime _date(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// 安排一次延迟落盘，避免连续输入时频繁写库。
  void scheduleSave() {
    _savePending = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _savePending = false;
      _persist();
    });
  }

  /// 立即写盘（导出备份、锁屏、清空数据前调用）。
  Future<void> flush() async {
    _saveTimer?.cancel();
    _savePending = false;
    await _persist();
  }

  bool get hasPendingSave => _savePending;

  Future<void> _persist() async {
    final key = _key;
    if (key == null || !store.isReady) return;

    await store.writeMap(LocalStore.keySettings, settings.toMap());

    final passwordMaps = <Map<String, dynamic>>[];
    for (final entry in passwords) {
      final map = entry.toPlainMap();
      map['username'] = await crypto.encryptString(key, entry.username);
      map['password'] = await crypto.encryptString(key, entry.password);
      map['notes'] = await crypto.encryptString(key, entry.notes);
      passwordMaps.add(map);
    }
    await store.writeList(LocalStore.keyPasswords, passwordMaps);

    final noteMaps = <Map<String, dynamic>>[];
    for (final note in notes) {
      final map = note.toPlainMap();
      if (note.encrypted) {
        map['content'] = await crypto.encryptString(key, note.content);
      }
      noteMaps.add(map);
    }
    await store.writeList(LocalStore.keyNotes, noteMaps);

    await store.writeList(
      LocalStore.keyTodos,
      todos.map((e) => e.toPlainMap()).toList(),
    );
    await store.writeList(
      LocalStore.keyCountdowns,
      countdowns.map((e) => e.toPlainMap()).toList(),
    );
    await store.writeList(
      LocalStore.keyFiles,
      files.map((e) => e.toPlainMap()).toList(),
    );
  }

  // ---------------------------------------------------------------- 密码本

  void upsertPassword(PasswordEntry entry) {
    final index = passwords.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      passwords[index] = entry;
    } else {
      passwords.insert(0, entry);
    }
    scheduleSave();
    notifyListeners();
  }

  // ---------------------------------------------------------------- 备忘录

  void upsertNote(Note note) {
    final index = notes.indexWhere((e) => e.id == note.id);
    if (index >= 0) {
      notes[index] = note;
    } else {
      notes.insert(0, note);
    }
    scheduleSave();
    notifyListeners();
  }

  // ---------------------------------------------------------------- 待办

  void upsertTodo(TodoItem todo) {
    final index = todos.indexWhere((e) => e.id == todo.id);
    if (index >= 0) {
      todos[index] = todo;
    } else {
      final maxOrder = todos.isEmpty
          ? 0
          : todos.map((e) => e.order).reduce((a, b) => a > b ? a : b);
      todos.add(todo.copyWith(order: maxOrder + 1));
    }
    scheduleSave();
    notifyListeners();
  }

  /// 勾选 / 取消勾选。勾选重复待办时会自动生成下一次的条目。
  void setTodoDone(String id, bool done) {
    final index = todos.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final item = todos[index];
    todos[index] = item.copyWith(done: done, updatedAt: DateTime.now());

    if (done && item.repeat != TodoRepeat.none) {
      final next = item.repeat.nextDate(item.dueDate);
      if (next != null) {
        final maxOrder = todos.isEmpty
            ? 0
            : todos.map((e) => e.order).reduce((a, b) => a > b ? a : b);
        todos.add(TodoItem(
          id: WuUtils.newId(),
          title: item.title,
          note: item.note,
          dueDate: next,
          priority: item.priority,
          repeat: item.repeat,
          subtasks: [
            for (final sub in item.subtasks)
              TodoSubtask(id: WuUtils.newId(), title: sub.title),
          ],
          order: maxOrder + 1,
        ));
      }
    }
    scheduleSave();
    notifyListeners();
  }

  void toggleSubtask(String todoId, String subtaskId) {
    final index = todos.indexWhere((e) => e.id == todoId);
    if (index < 0) return;
    final item = todos[index];
    final updated = item.subtasks
        .map((sub) => sub.id == subtaskId ? sub.copyWith(done: !sub.done) : sub)
        .toList();
    todos[index] = item.copyWith(subtasks: updated, updatedAt: DateTime.now());
    scheduleSave();
    notifyListeners();
  }

  /// 拖拽排序后写入新的序号。
  void applyTodoOrder(List<String> orderedIds) {
    for (int i = 0; i < orderedIds.length; i++) {
      final index = todos.indexWhere((e) => e.id == orderedIds[i]);
      if (index >= 0) {
        todos[index] = todos[index].copyWith(order: i, updatedAt: DateTime.now());
      }
    }
    scheduleSave();
    notifyListeners();
  }

  /// 归档所有已完成的待办。
  int archiveCompleted() {
    int count = 0;
    todos = todos.map((item) {
      if (item.done && !item.archived) {
        count++;
        return item.copyWith(archived: true, updatedAt: DateTime.now());
      }
      return item;
    }).toList();
    if (count > 0) {
      scheduleSave();
      notifyListeners();
    }
    return count;
  }

  // ---------------------------------------------------------------- 倒数日

  void upsertCountdown(CountdownItem item) {
    final index = countdowns.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      countdowns[index] = item;
    } else {
      countdowns.add(item);
    }
    scheduleSave();
    notifyListeners();
  }

  // ---------------------------------------------------------------- 文件库

  void upsertFile(FileItem item) {
    final index = files.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      files[index] = item;
    } else {
      files.insert(0, item);
    }
    scheduleSave();
    notifyListeners();
  }

  // ---------------------------------------------------------------- 回收站

  /// 把条目移入回收站（不删除附件文件，便于恢复）。
  void moveToTrash(EntityType type, String id) {
    final now = DateTime.now();
    switch (type) {
      case EntityType.password:
        final index = passwords.indexWhere((e) => e.id == id);
        if (index < 0) return;
        passwords[index] = passwords[index].copyWith(deletedAt: now);
        break;
      case EntityType.note:
        final index = notes.indexWhere((e) => e.id == id);
        if (index < 0) return;
        notes[index] = notes[index].copyWith(deletedAt: now);
        break;
      case EntityType.todo:
        final index = todos.indexWhere((e) => e.id == id);
        if (index < 0) return;
        todos[index] = todos[index].copyWith(deletedAt: now);
        break;
      case EntityType.countdown:
        final index = countdowns.indexWhere((e) => e.id == id);
        if (index < 0) return;
        countdowns[index] = countdowns[index].copyWith(deletedAt: now);
        break;
      case EntityType.file:
        final index = files.indexWhere((e) => e.id == id);
        if (index < 0) return;
        files[index] = files[index].copyWith(deletedAt: now);
        break;
    }
    scheduleSave();
    notifyListeners();
  }

  void restoreFromTrash(EntityType type, String id) {
    switch (type) {
      case EntityType.password:
        final index = passwords.indexWhere((e) => e.id == id);
        if (index < 0) return;
        passwords[index] = passwords[index].copyWith(clearDeletedAt: true);
        break;
      case EntityType.note:
        final index = notes.indexWhere((e) => e.id == id);
        if (index < 0) return;
        notes[index] = notes[index].copyWith(clearDeletedAt: true);
        break;
      case EntityType.todo:
        final index = todos.indexWhere((e) => e.id == id);
        if (index < 0) return;
        todos[index] = todos[index].copyWith(clearDeletedAt: true);
        break;
      case EntityType.countdown:
        final index = countdowns.indexWhere((e) => e.id == id);
        if (index < 0) return;
        countdowns[index] = countdowns[index].copyWith(clearDeletedAt: true);
        break;
      case EntityType.file:
        final index = files.indexWhere((e) => e.id == id);
        if (index < 0) return;
        files[index] = files[index].copyWith(clearDeletedAt: true);
        break;
    }
    scheduleSave();
    notifyListeners();
  }

  /// 彻底删除（不可恢复），会连同附件一起删除。
  Future<void> purgeFromTrash(EntityType type, String id) async {
    switch (type) {
      case EntityType.password:
        passwords.removeWhere((e) => e.id == id);
        break;
      case EntityType.note:
        final note = _findById(notes, id, (e) => e.id);
        if (note != null) {
          for (final image in note.images) {
            await attachments.delete(image);
          }
        }
        notes.removeWhere((e) => e.id == id);
        break;
      case EntityType.todo:
        todos.removeWhere((e) => e.id == id);
        break;
      case EntityType.countdown:
        countdowns.removeWhere((e) => e.id == id);
        break;
      case EntityType.file:
        final file = _findById(files, id, (e) => e.id);
        if (file != null) {
          await attachments.delete(file.storedName);
        }
        files.removeWhere((e) => e.id == id);
        break;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> emptyTrash() async {
    for (final item in trashRecords) {
      await purgeFromTrash(item.type, item.id);
    }
  }

  /// 回收站列表（按删除时间倒序）。
  List<TrashRecord> get trashRecords {
    final records = <TrashRecord>[
      for (final e in passwords.where((e) => e.inTrash))
        TrashRecord(
          type: EntityType.password,
          id: e.id,
          title: e.title,
          subtitle: e.tags.join(' · '),
          deletedAt: e.deletedAt!,
        ),
      for (final e in notes.where((e) => e.inTrash))
        TrashRecord(
          type: EntityType.note,
          id: e.id,
          title: e.displayTitle,
          subtitle: e.tags.join(' · '),
          deletedAt: e.deletedAt!,
        ),
      for (final e in todos.where((e) => e.inTrash))
        TrashRecord(
          type: EntityType.todo,
          id: e.id,
          title: e.title,
          subtitle: '',
          deletedAt: e.deletedAt!,
        ),
      for (final e in countdowns.where((e) => e.inTrash))
        TrashRecord(
          type: EntityType.countdown,
          id: e.id,
          title: e.title,
          subtitle: '',
          deletedAt: e.deletedAt!,
        ),
      for (final e in files.where((e) => e.inTrash))
        TrashRecord(
          type: EntityType.file,
          id: e.id,
          title: e.displayName,
          subtitle: WuUtils.formatSize(e.size),
          deletedAt: e.deletedAt!,
        ),
    ];
    records.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return records;
  }

  // ---------------------------------------------------------------- 备份

  /// 导出用的明文数据快照。
  Map<String, dynamic> exportSnapshot() => {
        'schema': 1,
        'passwords': passwords.map((e) => e.toPlainMap()).toList(),
        'notes': notes.map((e) => e.toPlainMap()).toList(),
        'todos': todos.map((e) => e.toPlainMap()).toList(),
        'countdowns': countdowns.map((e) => e.toPlainMap()).toList(),
        'files': files.map((e) => e.toPlainMap()).toList(),
      };

  /// 收集需要打包进备份的附件。
  Future<List<BackupAsset>> collectAssets() async {
    final names = <String>{};
    for (final file in files) {
      names.add(file.storedName);
    }
    for (final note in notes) {
      names.addAll(note.images);
    }
    final assets = <BackupAsset>[];
    for (final name in names) {
      final path = attachments.pathOf(name);
      if (path == null) continue;
      if (!await attachments.exists(name)) continue;
      assets.add(BackupAsset(
        storedName: name,
        path: path,
        size: await attachments.sizeOf(name),
      ));
    }
    return assets;
  }

  /// 导入备份。[overwrite] 为 true 时是覆盖模式：清空本地旧数据与附件。
  Future<ImportSummary> importBackup({
    required BackupContent content,
    required bool overwrite,
    void Function(double progress)? onProgress,
    void Function(String message)? onMessage,
  }) async {
    final data = content.data;
    final summary = ImportSummary();

    if (overwrite) {
      await attachments.wipe();
      passwords = [];
      notes = [];
      todos = [];
      countdowns = [];
      files = [];
    }

    // 第一步：把附件还原到附件目录
    final dirPath = attachments.directoryPath;
    if (dirPath != null && content.assets.isNotEmpty) {
      onMessage?.call('正在还原附件…');
      await backup.restoreAssets(
        path: content.storagePath,
        content: content,
        targetDirectory: dirPath,
        onProgress: onProgress,
        onAssetWritten: (name, path) {},
      );
    }

    // 第二步：合并结构化数据
    final importedPasswords = _maps(data['passwords'])
        .map(PasswordEntry.fromPlainMap)
        .toList();
    for (final item in importedPasswords) {
      final exists = passwords.any((e) => e.id == item.id);
      passwords.add(exists ? _clonePassword(item) : item);
      summary.passwords++;
    }

    final importedNotes = _maps(data['notes']).map(Note.fromPlainMap).toList();
    for (final item in importedNotes) {
      final exists = notes.any((e) => e.id == item.id);
      notes.add(exists ? _cloneNote(item) : item);
      summary.notes++;
    }

    final importedTodos = _maps(data['todos']).map(TodoItem.fromPlainMap).toList();
    int nextOrder = todos.isEmpty
        ? 0
        : todos.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 1;
    for (final item in importedTodos) {
      final exists = todos.any((e) => e.id == item.id);
      final target = exists ? _cloneTodo(item) : item;
      todos.add(target.copyWith(order: nextOrder));
      nextOrder++;
      summary.todos++;
    }

    final importedCountdowns =
        _maps(data['countdowns']).map(CountdownItem.fromPlainMap).toList();
    for (final item in importedCountdowns) {
      final exists = countdowns.any((e) => e.id == item.id);
      countdowns.add(exists ? _cloneCountdown(item) : item);
      summary.countdowns++;
    }

    final importedFiles = _maps(data['files']).map(FileItem.fromPlainMap).toList();
    for (final item in importedFiles) {
      final idExists = files.any((e) => e.id == item.id);
      // 同名附件已存在（重复导入同一份备份）时，复制出一份新的文件名，避免互相影响
      final nameExists = !overwrite && files.any((e) => e.storedName == item.storedName);
      String storedName = item.storedName;
      if (nameExists && attachments.supported) {
        try {
          storedName = await attachments.duplicate(item.storedName);
        } catch (_) {
          storedName = item.storedName;
        }
      }
      files.add(idExists || nameExists
          ? FileItem(
              id: WuUtils.newId(),
              originalName: item.originalName,
              storedName: storedName,
              size: item.size,
              note: item.note,
              tags: item.tags,
              createdAt: item.createdAt,
              deletedAt: item.deletedAt,
            )
          : item);
      summary.files++;
    }

    await _persist();
    notifyListeners();
    return summary;
  }

  T? _findById<T>(List<T> items, String id, String Function(T item) idOf) {
    for (final item in items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  PasswordEntry _clonePassword(PasswordEntry item) => PasswordEntry(
        id: WuUtils.newId(),
        title: item.title,
        username: item.username,
        password: item.password,
        notes: item.notes,
        tags: item.tags,
        pinned: item.pinned,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        deletedAt: item.deletedAt,
      );

  Note _cloneNote(Note item) => Note(
        id: WuUtils.newId(),
        title: item.title,
        content: item.content,
        images: item.images,
        tags: item.tags,
        pinned: item.pinned,
        encrypted: item.encrypted,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        deletedAt: item.deletedAt,
      );

  TodoItem _cloneTodo(TodoItem item) => TodoItem(
        id: WuUtils.newId(),
        title: item.title,
        note: item.note,
        dueDate: item.dueDate,
        priority: item.priority,
        repeat: item.repeat,
        subtasks: item.subtasks,
        done: item.done,
        archived: item.archived,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        deletedAt: item.deletedAt,
      );

  CountdownItem _cloneCountdown(CountdownItem item) => CountdownItem(
        id: WuUtils.newId(),
        title: item.title,
        targetDate: item.targetDate,
        note: item.note,
        tags: item.tags,
        pinned: item.pinned,
        colorIndex: item.colorIndex,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        deletedAt: item.deletedAt,
      );

  /// 清除所有本地条目与附件（保留解锁密码与外观设置）。
  Future<void> clearLocalData() async {
    passwords = [];
    notes = [];
    todos = [];
    countdowns = [];
    files = [];
    await attachments.wipe();
    await _persist();
    notifyListeners();
  }
}

/// 导入结果统计。
class ImportSummary {
  int passwords = 0;
  int notes = 0;
  int todos = 0;
  int countdowns = 0;
  int files = 0;

  int get total => passwords + notes + todos + countdowns + files;
}
