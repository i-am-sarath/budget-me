import 'dart:convert';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_money/core/services/cloud_service.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';

/// One-way Google Sheets sync (app → user's own sheet).
///
/// Privacy-first by design: it requests only the **`drive.file`** scope, which
/// grants access to *just the one spreadsheet this app creates* — it can never
/// see any of the user's other Drive files. That keeps the feature aligned with
/// the app's "we don't touch your data" positioning and avoids Google's
/// sensitive-scope verification.
///
/// Sync is opt-in. When connected, every new transaction is appended as a row.
/// Failed writes (offline) are queued in SharedPreferences and flushed on the
/// next successful append or on reconnect.
class SheetsSyncService {
  SheetsSyncService._();
  static final SheetsSyncService instance = SheetsSyncService._();

  static const _kSpreadsheetId = 'sheets_spreadsheet_id';
  static const _kSpreadsheetUrl = 'sheets_spreadsheet_url';
  static const _kConnectedEmail = 'sheets_connected_email';
  static const _kPendingQueue = 'sheets_pending_rows';

  static const _scope = 'https://www.googleapis.com/auth/drive.file';
  static const _sheetName = 'Transactions';

  // IMPORTANT: reuse the ONE app-wide GoogleSignIn from CloudService rather
  // than creating a second instance. Two differently-configured GoogleSignIn
  // objects reconfigure the native client and cause DEVELOPER_ERROR (10) on the
  // next sign-in. The drive.file scope is added incrementally via requestScopes
  // in connect(), so the shared instance needs no extra scopes up front.
  GoogleSignIn get _googleSignIn => CloudService.googleSignIn;

  bool _connected = false;
  String? _spreadsheetId;
  String? _spreadsheetUrl;
  String? _email;

  bool get isConnected => _connected;
  String? get connectedEmail => _email;
  String? get spreadsheetUrl => _spreadsheetUrl;

  /// Load persisted connection state. Call once at startup.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _spreadsheetId = prefs.getString(_kSpreadsheetId);
    _spreadsheetUrl = prefs.getString(_kSpreadsheetUrl);
    _email = prefs.getString(_kConnectedEmail);
    _connected = _spreadsheetId != null && _spreadsheetId!.isNotEmpty;
    // Opportunistically flush anything queued while offline last session.
    if (_connected) {
      unawaitedFlush();
    }
  }

  /// Connect: sign in with the drive.file scope, create the spreadsheet, and
  /// write the header row. Returns null on success, or an error message.
  Future<String?> connect() async {
    try {
      final account =
          _googleSignIn.currentUser ?? await _googleSignIn.signIn();
      if (account == null) return 'Sign-in cancelled';

      // Make sure the drive.file scope is actually granted (incremental auth).
      // If the OAuth consent screen doesn't list drive.file, this returns false.
      final granted = await _googleSignIn.requestScopes([_scope]);
      if (!granted) {
        return 'Google Sheets permission was not granted. '
            'Make sure the app is allowed to create Sheets.';
      }

      final token = (await account.authentication).accessToken;
      if (token == null) return 'Could not get a Google access token';

      final created = await _createSpreadsheet(token);
      if (created.error != null) return created.error;
      final id = created.id!;

      await _writeHeader(token, id);

      final prefs = await SharedPreferences.getInstance();
      final url = 'https://docs.google.com/spreadsheets/d/$id';
      await prefs.setString(_kSpreadsheetId, id);
      await prefs.setString(_kSpreadsheetUrl, url);
      await prefs.setString(_kConnectedEmail, account.email);

      _spreadsheetId = id;
      _spreadsheetUrl = url;
      _email = account.email;
      _connected = true;
      return null;
    } on PlatformException catch (e) {
      // ApiException: 10 (DEVELOPER_ERROR) → the OAuth Android client / SHA-1
      // isn't registered for this app in Google Cloud console.
      if (e.code == 'sign_in_failed' && (e.message?.contains('10') ?? false)) {
        return 'Google sign-in isn\'t set up for this app yet '
            '(developer error 10 — missing OAuth client / SHA-1).';
      }
      return 'Google sign-in failed: ${e.code} ${e.message ?? ''}'.trim();
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  Future<void> disconnect() async {
    // Do NOT sign out of Google here — the GoogleSignIn instance is shared with
    // app auth, so signing out would log the user out entirely. Disconnecting
    // Sheets just forgets the linked spreadsheet; the drive.file grant remains
    // but is harmless and is dropped when the user fully signs out.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSpreadsheetId);
    await prefs.remove(_kSpreadsheetUrl);
    await prefs.remove(_kConnectedEmail);
    await prefs.remove(_kPendingQueue);
    _spreadsheetId = null;
    _spreadsheetUrl = null;
    _email = null;
    _connected = false;
  }

  /// Append a transaction as a new row. Fire-and-forget safe — on failure the
  /// row is queued and retried later. No-op when not connected.
  Future<void> appendTransaction(TransactionModel tx) async {
    if (!_connected) return;
    final row = _rowFor(tx);
    final ok = await _appendRows([row]);
    if (!ok) {
      await _enqueue(row);
    } else {
      // A successful write is a good moment to drain the backlog.
      await _flushPending();
    }
  }

  void unawaitedFlush() {
    // ignore: discarded_futures
    _flushPending();
  }

  // ── Sheets / Drive REST ───────────────────────────────────

  Future<String?> _freshToken() async {
    final account =
        _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) return null;
    return (await account.authentication).accessToken;
  }

  Future<({String? id, String? error})> _createSpreadsheet(String token) async {
    final res = await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'properties': {'title': 'Budget Me — Transactions'},
        'sheets': [
          {
            'properties': {'title': _sheetName},
          }
        ],
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (id: data['spreadsheetId'] as String?, error: null);
    }
    // Surface the real reason — most commonly a 403 because the drive.file
    // scope isn't enabled on the OAuth consent screen, or the Sheets API
    // isn't enabled for the Cloud project.
    final snippet =
        res.body.length > 180 ? res.body.substring(0, 180) : res.body;
    return (id: null, error: 'Sheets API error ${res.statusCode}: $snippet');
  }

  Future<void> _writeHeader(String token, String spreadsheetId) async {
    await _appendRowsWith(token, spreadsheetId, [
      ['Date', 'Type', 'Category', 'Amount', 'Note', 'Payee', 'Account', 'ID'],
    ]);
  }

  Future<bool> _appendRows(List<List<String>> rows) async {
    final id = _spreadsheetId;
    if (id == null) return false;
    final token = await _freshToken();
    if (token == null) return false;
    return _appendRowsWith(token, id, rows);
  }

  Future<bool> _appendRowsWith(
    String token,
    String spreadsheetId,
    List<List<String>> rows,
  ) async {
    try {
      final res = await http.post(
        Uri.parse(
          'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/'
          '$_sheetName!A1:append?valueInputOption=USER_ENTERED',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'values': rows}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  List<String> _rowFor(TransactionModel tx) {
    return [
      DateFormat('yyyy-MM-dd').format(tx.date),
      tx.type.label,
      tx.category,
      tx.amount.toStringAsFixed(2),
      tx.note,
      tx.payee ?? '',
      tx.accountName ?? '',
      tx.id,
    ];
  }

  // ── Offline queue ─────────────────────────────────────────

  Future<void> _enqueue(List<String> row) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kPendingQueue) ?? [];
    raw.add(jsonEncode(row));
    await prefs.setStringList(_kPendingQueue, raw);
  }

  Future<void> _flushPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kPendingQueue) ?? [];
    if (raw.isEmpty) return;
    final rows = raw
        .map((e) => (jsonDecode(e) as List).map((c) => c.toString()).toList())
        .toList();
    final ok = await _appendRows(rows);
    if (ok) {
      await prefs.remove(_kPendingQueue);
    }
  }
}

/// Riverpod state for the settings "Connect Google Sheets" tile.
class SheetsSyncState {
  final bool connected;
  final String? email;
  final String? url;
  final bool isBusy;
  const SheetsSyncState({
    this.connected = false,
    this.email,
    this.url,
    this.isBusy = false,
  });

  SheetsSyncState copyWith({
    bool? connected,
    String? email,
    String? url,
    bool? isBusy,
  }) =>
      SheetsSyncState(
        connected: connected ?? this.connected,
        email: email ?? this.email,
        url: url ?? this.url,
        isBusy: isBusy ?? this.isBusy,
      );
}

class SheetsSyncNotifier extends StateNotifier<SheetsSyncState> {
  SheetsSyncNotifier() : super(const SheetsSyncState()) {
    _load();
  }

  final _svc = SheetsSyncService.instance;

  Future<void> _load() async {
    await _svc.restore();
    state = SheetsSyncState(
      connected: _svc.isConnected,
      email: _svc.connectedEmail,
      url: _svc.spreadsheetUrl,
    );
  }

  /// Returns null on success or an error message.
  Future<String?> connect() async {
    state = state.copyWith(isBusy: true);
    final err = await _svc.connect();
    state = SheetsSyncState(
      connected: _svc.isConnected,
      email: _svc.connectedEmail,
      url: _svc.spreadsheetUrl,
      isBusy: false,
    );
    return err;
  }

  Future<void> disconnect() async {
    state = state.copyWith(isBusy: true);
    await _svc.disconnect();
    state = const SheetsSyncState(isBusy: false);
  }
}

final sheetsSyncProvider =
    StateNotifierProvider<SheetsSyncNotifier, SheetsSyncState>(
  (ref) => SheetsSyncNotifier(),
);
