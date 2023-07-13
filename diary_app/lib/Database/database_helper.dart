import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/diary_entry.dart';

class DatabaseHelper {
  static const _databaseName = 'diary.db';
  static const _databaseVersion = 1;

  static const table = 'entries';

  static const columnId = 'id';
  static const columnTitle = 'title';
  static const columnDate = 'date';
  static const columnDescription = 'description';
  static const columnPhoto = 'photo';
  static const columnAudio = 'audio';

  static Database? _database;

  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTitle TEXT NOT NULL,
        $columnDate TEXT NOT NULL,
        $columnDescription TEXT NOT NULL,
        $columnPhoto TEXT,
        $columnAudio TEXT
      )
      ''');
  }

  Future<int> insert(DiaryEntry entry) async {
    Database db = await instance.database;
    return await db.insert(table, entry.toMap());
  }

  Future<List<DiaryEntry>> getEntries() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps =
        await db.query(table, orderBy: '$columnId DESC');
    return List.generate(maps.length, (i) {
      return DiaryEntry.fromMap(maps[i]);
    });
  }

  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> deleteAll() async {
    Database db = await instance.database;
    return await db.delete(table);
  }

  Future<int> updatePhoto(int id, String photo) async {
    Database db = await instance.database;
    return await db.update(
      table,
      {columnPhoto: photo},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateAudio(int id, String audioPath) async {
    Database db = await database;
    return await db.update(
      table,
      {columnAudio: audioPath},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
}
