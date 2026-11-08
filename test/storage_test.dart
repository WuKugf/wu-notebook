import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wu_notebook/core/utils.dart';
import 'package:wu_notebook/data/app_state.dart';
import 'package:wu_notebook/data/local_store.dart';
import 'package:wu_notebook/data/models/countdown_item.dart';
import 'package:wu_notebook/data/models/file_item.dart';
import 'package:wu_notebook/data/models/note.dart';
import 'package:wu_notebook/data/models/password_entry.dart';
import 'package:wu_notebook/data/models/todo_item.dart';

/// 数据层自查：真实 Hive（临时目录）+ 真实加密。
/// 覆盖：首次设置密码、敏感字段密文落盘、增删改查、回收站恢复、
/// 锁屏后重新解锁、修改密码、清除本地数据。
void main() {
  late Directory tempDir;
  late AppState state;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wu_store_test');
    state = AppState();
    AppState.instance = state;
    await state.bootstrap(storagePath: tempDir.path);
    state.setAutoLockMinutes(0);
  });

  tearDown(() async {
    await state.flush();
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // 忽略 Windows 上仍被占用的文件
      }
    }
  });

  test('密码本条目以密文落盘，重新解锁后能还原', () async {
    await state.setupPassword('test123456');

    state.upsertPassword(PasswordEntry(
      id: WuUtils.newId(),
      title: '邮箱',
      username: 'me@example.com',
      password: 'plain-secret',
      notes: 'https://example.com',
      tags: const ['工作'],
    ));
    await state.flush();

    final raw = LocalStore.instance.readList(LocalStore.keyPasswords);
    expect(raw, hasLength(1));
    expect(raw.first['password'], isNot('plain-secret'));
    expect(raw.first['username'], isNot('me@example.com'));

    // 锁屏后内存清空，重新解锁数据回来
    await state.lockNow();
    expect(state.passwords, isEmpty);
    expect(await state.unlock('wrong-password'), isFalse);
    expect(await state.unlock('test123456'), isTrue);
    expect(state.passwords, hasLength(1));
    expect(state.passwords.first.password, 'plain-secret');
    expect(state.passwords.first.username, 'me@example.com');
    expect(state.passwords.first.tags, ['工作']);
  });

  test('加密笔记只有解锁后才解密，普通笔记保持明文', () async {
    await state.setupPassword('test123456');

    state.upsertNote(Note(
      id: WuUtils.newId(),
      title: '私密',
      content: '只有我知道的内容',
      encrypted: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    state.upsertNote(Note(
      id: WuUtils.newId(),
      title: '日常',
      content: '公开的备忘',
      encrypted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    await state.flush();

    final rawNotes = LocalStore.instance.readList(LocalStore.keyNotes);
    final encryptedRaw =
        rawNotes.firstWhere((e) => (e as Map)['title'] == '私密');
    expect(encryptedRaw['content'], isNot('只有我知道的内容'));

    await state.lockNow();
    await state.unlock('test123456');
    final private = state.notes.firstWhere((e) => e.title == '私密');
    expect(private.content, '只有我知道的内容');
  });

  test('回收站可以恢复密码、待办、倒数日与文件记录', () async {
    await state.setupPassword('test123456');

    final password = PasswordEntry(
      id: WuUtils.newId(),
      title: '站点',
      username: 'u',
      password: 'p',
    );
    final todo = TodoItem(
      id: WuUtils.newId(),
      title: '买菜',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final countdown = CountdownItem(
      id: WuUtils.newId(),
      title: '生日',
      targetDate: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final file = FileItem(
      id: WuUtils.newId(),
      originalName: 'a.txt',
      storedName: 'a.txt',
      size: 10,
      createdAt: DateTime.now(),
    );

    state.upsertPassword(password);
    state.upsertTodo(todo);
    state.upsertCountdown(countdown);
    state.upsertFile(file);
    await state.flush();

    state.moveToTrash(EntityType.password, password.id);
    state.moveToTrash(EntityType.todo, todo.id);
    state.moveToTrash(EntityType.countdown, countdown.id);
    state.moveToTrash(EntityType.file, file.id);
    await state.flush();

    expect(state.passwords.where((e) => !e.inTrash), isEmpty);
    expect(state.trashRecords, hasLength(4));

    for (final record in state.trashRecords.toList()) {
      state.restoreFromTrash(record.type, record.id);
    }
    await state.flush();

    expect(state.passwords.where((e) => !e.inTrash), hasLength(1));
    expect(state.todos.where((e) => !e.inTrash), hasLength(1));
    expect(state.countdowns.where((e) => !e.inTrash), hasLength(1));
    expect(state.files.where((e) => !e.inTrash), hasLength(1));
    expect(state.trashRecords, isEmpty);
  });

  test('重复待办完成后自动生成下一次', () async {
    await state.setupPassword('test123456');

    final due = DateTime.now().add(const Duration(days: 1));
    final todo = TodoItem(
      id: WuUtils.newId(),
      title: '每周浇水',
      repeat: TodoRepeat.weekly,
      dueDate: due,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    state.upsertTodo(todo);
    state.setTodoDone(todo.id, true);
    await state.flush();

    final active = state.todos.where((e) => !e.done && !e.inTrash).toList();
    expect(active, hasLength(1));
    expect(active.first.title, '每周浇水');
    expect(
      active.first.dueDate!.difference(due).inDays,
      7,
    );
    expect(state.todos.firstWhere((e) => e.id == todo.id).done, isTrue);
  });

  test('修改解锁密码后旧密码失效、数据仍可读', () async {
    await state.setupPassword('old123456');
    state.upsertPassword(PasswordEntry(
      id: WuUtils.newId(),
      title: '邮箱',
      username: 'me',
      password: 'secret',
    ));
    await state.flush();

    await state.changePassword('new123456');
    await state.flush();

    await state.lockNow();
    expect(await state.unlock('old123456'), isFalse);
    expect(await state.unlock('new123456'), isTrue);
    expect(state.passwords.first.password, 'secret');
  });

  test('清除本地数据会清空全部条目但保留解锁密码', () async {
    await state.setupPassword('test123456');
    state.upsertPassword(PasswordEntry(
      id: WuUtils.newId(),
      title: '邮箱',
      username: 'me',
      password: 'secret',
    ));
    await state.flush();

    await state.clearLocalData();
    await state.flush();

    expect(state.passwords, isEmpty);
    expect(state.notes, isEmpty);
    expect(state.todos, isEmpty);
    expect(state.countdowns, isEmpty);
    expect(state.files, isEmpty);

    await state.lockNow();
    expect(await state.unlock('test123456'), isTrue);
  });
}
