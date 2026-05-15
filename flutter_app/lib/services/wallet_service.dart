import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

class WalletService extends ChangeNotifier {
  static final WalletService _instance = WalletService._();
  factory WalletService() => _instance;
  WalletService._();

  final http.Client _client = http.Client();

  String? _address;
  int _balance = 0;
  bool _connected = false;
  bool _connecting = false;

  String? get address => _address;
  int get balance => _balance;
  bool get connected => _connected;
  bool get connecting => _connecting;

  Future<void> connect() async {
    if (_connecting) return;
    _connecting = true;
    notifyListeners();

    try {
      final addrResp = await _client
          .get(Uri.parse('${AppConstants.apiBaseUrl}/blockchain/address'))
          .timeout(const Duration(seconds: 15));
      if (addrResp.statusCode == 200) {
        final data = jsonDecode(addrResp.body);
        _address = data['address'] as String?;
      }

      final balResp = await _client
          .get(Uri.parse('${AppConstants.apiBaseUrl}/blockchain/balance'))
          .timeout(const Duration(seconds: 15));
      if (balResp.statusCode == 200) {
        final data = jsonDecode(balResp.body);
        _balance = data['balance'] as int? ?? 0;
      }

      _connected = _address != null;
    } catch (e) {
      debugPrint('[Wallet] connect error: $e');
    }

    _connecting = false;
    notifyListeners();
  }

  Future<void> disconnect() async {
    _address = null;
    _balance = 0;
    _connected = false;
    notifyListeners();
  }

  Future<bool> sendDada(String to, int amount, {String? memo}) async {
    if (!_connected) return false;
    try {
      final resp = await _client
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}/blockchain/reward'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'to': to, 'amount': amount, 'memo': memo ?? ''}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _balance -= amount;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[Wallet] sendDada error: $e');
    }
    return false;
  }

  Future<void> refreshBalance() async {
    try {
      final resp = await _client
          .get(Uri.parse('${AppConstants.apiBaseUrl}/blockchain/balance'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _balance = data['balance'] as int? ?? _balance;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Wallet] refresh error: $e');
    }
  }

  Future<String> signTransaction(String txData) async {
    return 'signed_${txData.hashCode}';
  }

  String get shortAddress =>
      _address != null && _address!.length > 10
          ? '${_address!.substring(0, 6)}...${_address!.substring(_address!.length - 4)}'
          : _address ?? '';

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
