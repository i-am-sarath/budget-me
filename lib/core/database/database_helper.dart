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
      version: 5, // v5: categories + category_budgets tables
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
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

    await db.execute('''
      CREATE TABLE accounts (
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

    await db.execute('''
      CREATE TABLE subscriptions (
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

    await db.execute('''
      CREATE TABLE recurring_transactions (
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

    await _createCategoryTables(db);
    await _seedDefaultCategories(db);
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
      await _createCategoryTables(db);
      await _seedDefaultCategories(db);
    }
  }

  Future<void> _createCategoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '⚙️',
        type TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_budgets (
        id TEXT PRIMARY KEY,
        category_name TEXT NOT NULL,
        month_id TEXT NOT NULL,
        limit_amount REAL NOT NULL DEFAULT 0,
        UNIQUE(category_name, month_id)
      )
    ''');
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final seeds = <List<Object>>[
      // expense (sort_order, id, name, emoji)
      [0,  'd_exp_food',   'Food & Dining',    '🍔', 'expense'],
      [1,  'd_exp_trans',  'Transport',         '🚗', 'expense'],
      [2,  'd_exp_shop',   'Shopping',          '🛍️', 'expense'],
      [3,  'd_exp_house',  'Housing',           '🏠', 'expense'],
      [4,  'd_exp_health', 'Health',            '💊', 'expense'],
      [5,  'd_exp_bills',  'Bills & Utilities', '📱', 'expense'],
      [6,  'd_exp_ent',    'Entertainment',     '🎬', 'expense'],
      [7,  'd_exp_edu',    'Education',         '📚', 'expense'],
      [8,  'd_exp_travel', 'Travel',            '✈️', 'expense'],
      [9,  'd_exp_cloth',  'Clothing',          '👗', 'expense'],
      [10, 'd_exp_pet',    'Pet Care',          '🐾', 'expense'],
      [11, 'd_exp_gen',    'General',           '⚙️', 'expense'],
      // income
      [0, 'd_inc_sal',   'Salary',        '💼', 'income'],
      [1, 'd_inc_free',  'Freelance',     '💰', 'income'],
      [2, 'd_inc_gift',  'Gift',          '🎁', 'income'],
      [3, 'd_inc_int',   'Interest',      '🏦', 'income'],
      [4, 'd_inc_rent',  'Rental Income', '🏡', 'income'],
      [5, 'd_inc_side',  'Side Business', '📦', 'income'],
      [6, 'd_inc_div',   'Dividends',     '💹', 'income'],
      [7, 'd_inc_oth',   'Other',         '⚙️', 'income'],
      // investment
      [0, 'd_inv_stk',  'Stocks',          '📈', 'investment'],
      [1, 'd_inv_mf',   'Mutual Fund',     '🏦', 'investment'],
      [2, 'd_inv_re',   'Real Estate',     '🏠', 'investment'],
      [3, 'd_inv_cry',  'Crypto',          '💎', 'investment'],
      [4, 'd_inv_gold', 'Gold / Metals',   '🪙', 'investment'],
      [5, 'd_inv_etf',  'ETF / Index',     '📊', 'investment'],
      [6, 'd_inv_fd',   'Fixed Deposit',   '💵', 'investment'],
      [7, 'd_inv_oth',  'Other',           '⚙️', 'investment'],
      // lend
      [0, 'd_len_fri',  'Friend',    '👤', 'lend'],
      [1, 'd_len_fam',  'Family',    '👨‍👩‍👧', 'lend'],
      [2, 'd_len_col',  'Colleague', '💼', 'lend'],
      [3, 'd_len_oth',  'Other',     '⚙️', 'lend'],
      // lendReturn
      [0, 'd_lr_fri',  'Friend',    '👤', 'lendReturn'],
      [1, 'd_lr_fam',  'Family',    '👨‍👩‍👧', 'lendReturn'],
      [2, 'd_lr_col',  'Colleague', '💼', 'lendReturn'],
      [3, 'd_lr_oth',  'Other',     '⚙️', 'lendReturn'],
      // borrow
      [0, 'd_bor_fri',  'Friend',      '👤', 'borrow'],
      [1, 'd_bor_fam',  'Family',      '👨‍👩‍👧', 'borrow'],
      [2, 'd_bor_bnk',  'Bank/Lender', '🏦', 'borrow'],
      [3, 'd_bor_col',  'Colleague',   '💼', 'borrow'],
      [4, 'd_bor_oth',  'Other',       '⚙️', 'borrow'],
      // borrowReturn
      [0, 'd_br_fri',  'Friend',         '👤', 'borrowReturn'],
      [1, 'd_br_fam',  'Family',         '👨‍👩‍👧', 'borrowReturn'],
      [2, 'd_br_bnk',  'Bank/Lender',    '🏦', 'borrowReturn'],
      [3, 'd_br_col',  'Colleague',      '💼', 'borrowReturn'],
      [4, 'd_br_loan', 'Loan Repayment', '💳', 'borrowReturn'],
      [5, 'd_br_oth',  'Other',          '⚙️', 'borrowReturn'],
    ];

    final batch = db.batch();
    for (final s in seeds) {
      batch.insert(
        'categories',
        {
          'id': s[1],
          'name': s[2],
          'emoji': s[3],
          'type': s[4],
          'sort_order': s[0],
          'is_default': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
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
    await db.delete('category_budgets');
    // Categories are kept — user-created categories survive a data reset.
  }
}
