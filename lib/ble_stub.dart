// Stub file for web platform where flutter_blue_plus is not available
// This allows the app to compile for web preview

class BluetoothDevice {}
class BluetoothService {}
class BluetoothCharacteristic {
  BluetoothCharacteristicProperties get properties => BluetoothCharacteristicProperties();
  Future<void> write(List<int> data, {bool withoutResponse = false}) async {}
}

class BluetoothCharacteristicProperties {
  bool get write => false;
  bool get writeWithoutResponse => false;
}

class FlutterBluePlus {
  static Future<bool> get isSupported async => false;
  static Future<void> startScan({Duration? timeout}) async {}
  static Future<void> stopScan() async {}
  static Stream<List<dynamic>> get scanResults => const Stream.empty();
}
