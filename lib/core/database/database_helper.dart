import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  /// Call this once from main() before any DB access on desktop platforms.
  static void initForDesktop() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'quicklog.db');
    return await openDatabase(
      path,
      version: 5, // v5: adds spaces table + space_id to all tables
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Spaces table
    await db.execute('''
      CREATE TABLE spaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '🏠',
        color_value INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    // Seed the default personal space
    await db.insert('spaces', {
      'id': 'personal',
      'name': 'Personal',
      'emoji': '🏠',
      'color_value': 0xFF2D6A2D,
      'created_at': DateTime(2024, 1, 1).toIso8601String(),
    });

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        space_id TEXT NOT NULL DEFAULT 'personal',
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        note TEXT DEFAULT '',
        payee TEXT DEFAULT '',
        account_id TEXT DEFAULT '',
        account_name TEXT DEFAULT '',
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Accounts table
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        space_id TEXT NOT NULL DEFAULT 'personal',
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        color_value INTEGER NOT NULL DEFAULT 4284955319,
        icon_code INTEGER NOT NULL DEFAULT 57520,
        bank_name TEXT DEFAULT '',
        account_number TEXT DEFAULT '',
        currency_code TEXT DEFAULT 'INR',
        created_at TEXT NOT NULL
      )
    ''');

    // Subscriptions table (OTT, bills, memberships)
    await db.execute('''
      CREATE TABLE subscriptions (
        id TEXT PRIMARY KEY,
        space_id TEXT NOT NULL DEFAULT 'personal',
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Other',
        amount REAL NOT NULL DEFAULT 0,
        billing_cycle TEXT NOT NULL DEFAULT 'monthly',
        next_due_date TEXT NOT NULL,
        color_value INTEGER NOT NULL DEFAULT 0,
        icon_code INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    // Recurring transactions table
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id TEXT PRIMARY KEY,
        space_id TEXT NOT NULL DEFAULT 'personal',
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL DEFAULT 'expense',
        category TEXT NOT NULL DEFAULT 'General',
        account_id TEXT DEFAULT '',
        account_name TEXT DEFAULT '',
        frequency TEXT NOT NULL DEFAULT 'monthly',
        start_date TEXT NOT NULL,
        next_run_date TEXT NOT NULL,
        last_run_date TEXT DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        note TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE transactions ADD COLUMN payee TEXT DEFAULT ''");
      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN account_id TEXT DEFAULT ''");
        await db.execute("ALTER TABLE transactions ADD COLUMN account_name TEXT DEFAULT ''");
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN account_id TEXT DEFAULT ''");
        await db.execute("ALTER TABLE transactions ADD COLUMN account_name TEXT DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            balance REAL NOT NULL DEFAULT 0,
            color_value INTEGER NOT NULL DEFAULT 4284955319,
            icon_code INTEGER NOT NULL DEFAULT 57520,
            bank_name TEXT DEFAULT '',
            account_number TEXT DEFAULT '',
            currency_code TEXT DEFAULT 'INR',
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      // Add subscriptions table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS subscriptions (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'Other',
            amount REAL NOT NULL DEFAULT 0,
            billing_cycle TEXT NOT NULL DEFAULT 'monthly',
            next_due_date TEXT NOT NULL,
            color_value INTEGER NOT NULL DEFAULT 0,
            icon_code INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
            notes TEXT DEFAULT '',
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}

      // Add recurring_transactions table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS recurring_transactions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            type TEXT NOT NULL DEFAULT 'expense',
            category TEXT NOT NULL DEFAULT 'General',
            account_id TEXT DEFAULT '',
            account_name TEXT DEFAULT '',
            frequency TEXT NOT NULL DEFAULT 'monthly',
            start_date TEXT NOT NULL,
            next_run_date TEXT NOT NULL,
            last_run_date TEXT DEFAULT '',
            is_active INTEGER NOT NULL DEFAULT 1,
            note TEXT DEFAULT '',
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      // Create spaces table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS spaces (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            emoji TEXT NOT NULL DEFAULT '🏠',
            color_value INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.insert('spaces', {
          'id': 'personal',
          'name': 'Personal',
          'emoji': '🏠',
          'color_value': 0xFF2D6A2D,
          'created_at': DateTime(2024, 1, 1).toIso8601String(),
        });
      } catch (_) {}

      // Add space_id to all existing tables (existing rows → 'personal')
      for (final table in [
        'transactions',
        'accounts',
        'subscriptions',
        'recurring_transactions',
      ]) {
        try {
          await db.execute(
              "ALTER TABLE $table ADD COLUMN space_id TEXT NOT NULL DEFAULT 'personal'");
        } catch (_) {}
      }
    }
  }

  // ─────────────────────────────────────────────
  // Generic CRUD
  // ─────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table,
      {String? whereClause,
      List<dynamic>? whereArgs,
      String orderBy = 'created_at DESC'}) async {
    final db = await database;
    return await db.query(
      table,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  Future<int> delete(String table, String id) async {
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> update(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  Future<List<Map<String, dynamic>>> queryByField(
      String table, String field, dynamic value) async {
    final db = await database;
    return await db.query(table,
        where: '$field = ?', whereArgs: [value], orderBy: 'date DESC');
  }

  // ─────────────────────────────────────────────
  // Account-specific: atomic balance update
  // ─────────────────────────────────────────────

  Future<void> adjustAccountBalance(String accountId, double delta) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE accounts SET balance = balance + ? WHERE id = ?',
      [delta, accountId],
    );
  }

  // ─────────────────────────────────────────────
  // Reset: wipe all user data from every table
  // ─────────────────────────────────────────────

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('accounts');
    await db.delete('recurring_transactions');
    await db.delete('subscriptions');
    // Remove all non-personal spaces; re-seed personal
    await db.delete('spaces', where: 'id != ?', whereArgs: ['personal']);
  }

  Future<void> clearDataForSpace(String spaceId) async {
    final db = await database;
    for (final t in const [
      'transactions',
      'accounts',
      'recurring_transactions',
      'subscriptions'
    ]) {
      await db.delete(t, where: 'space_id = ?', whereArgs: [spaceId]);
    }
  }
}
