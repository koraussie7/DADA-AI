import 'dart:math';
import 'package:flutter/foundation.dart';

class WalletService extends ChangeNotifier {
  static final WalletService _instance = WalletService._();
  factory WalletService() => _instance;
  WalletService._();

  String? _address;
  int _balance = 100;
  bool _connected = false;

  String? get address => _address;
  int get balance => _balance;
  bool get connected => _connected;

  Future<void> connect() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _address = '0x${Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    _balance = 100;
    _connected = true;
    notifyListeners();
  }

  Future<void> disconnect() async {
    _address = null;
    _balance = 0;
    _connected = false;
    notifyListeners();
  }

  Future<bool> sendDada(String to, int amount, {String? memo}) async {
    if (!_connected || _balance < amount) return false;
    await Future.delayed(const Duration(milliseconds: 500));
    _balance -= amount;
    notifyListeners();
    return true;
  }

  Future<String> signTransaction(String txData) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'signed_${txData.hashCode}';
  }

  String get shortAddress =>
      _address != null && _address!.length > 10
          ? '${_address!.substring(0, 6)}...${_address!.substring(_address!.length - 4)}'
          : _address ?? '';
}
