import 'package:shared_preferences/shared_preferences.dart';

class StoreService {
  static Future<String?> getStoreCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('store_code');
  }

  static Future<void> setStoreCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_code', code);
  }
}
