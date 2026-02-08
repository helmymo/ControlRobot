import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Device info for display
class BleDeviceInfo {
  final String name;
  final String id;
  final int rssi;
  final List<String> serviceUuids;
  final BluetoothDevice? nativeDevice;

  BleDeviceInfo({
    required this.name,
    required this.id,
    required this.rssi,
    this.serviceUuids = const [],
    this.nativeDevice,
  });
}

/// Abstract BLE service interface
abstract class BleService {
  factory BleService() {
    // Always use real BLE service - no mock data
    return RealBleService();
  }

  Future<void> initialize();
  Stream<List<BleDeviceInfo>> scan();
  void stopScan();
  Future<bool> connect(BleDeviceInfo device);
  Future<void> disconnect();
  Future<void> sendData(String data);
  void dispose();
}

/// Mock BLE service for web/desktop preview
class MockBleService implements BleService {
  @override
  Future<void> initialize() async {
    debugPrint('BLE Service: Running in preview mode (mock data)');
  }

  @override
  Stream<List<BleDeviceInfo>> scan() async* {
    yield [];
    await Future.delayed(const Duration(seconds: 1));
    yield [
      BleDeviceInfo(
        name: 'ESP32-Robot (Mock)',
        id: 'AA:BB:CC:DD:EE:FF',
        rssi: -45,
        serviceUuids: ['4fafc201-1fb5-459e-8fcc-c5c9c331914b'],
      ),
    ];
    await Future.delayed(const Duration(milliseconds: 500));
    yield [
      BleDeviceInfo(
        name: 'ESP32-Robot (Mock)',
        id: 'AA:BB:CC:DD:EE:FF',
        rssi: -45,
        serviceUuids: ['4fafc201-1fb5-459e-8fcc-c5c9c331914b'],
      ),
      BleDeviceInfo(
        name: 'ESP32-Tank (Mock)',
        id: '11:22:33:44:55:66',
        rssi: -62,
      ),
    ];
  }

  @override
  void stopScan() {}

  @override
  Future<bool> connect(BleDeviceInfo device) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return true;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendData(String data) async {
    await Future.delayed(const Duration(milliseconds: 10));
    debugPrint('Mock BLE Send: $data');
  }

  @override
  void dispose() {}
}

/// Real BLE service for mobile (Android/iOS)
class RealBleService implements BleService {
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;
  final StreamController<List<BleDeviceInfo>> _deviceController = StreamController<List<BleDeviceInfo>>.broadcast();
  final List<BleDeviceInfo> _discoveredDevices = [];
  
  // Your ESP32's UUIDs - these should match what's configured in main.dart
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  Future<void> initialize() async {
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('BLE Service: Bluetooth not supported on this device');
        return;
      }
      debugPrint('BLE Service: Initialized successfully');
    } catch (e) {
      debugPrint('BLE Service: Initialize error - $e');
    }
  }

  @override
  Stream<List<BleDeviceInfo>> scan() {
    _discoveredDevices.clear();
    _startScanning();
    return _deviceController.stream;
  }
  
  Future<void> _startScanning() async {
    try {
      // Check Bluetooth adapter state first
      final adapterState = await FlutterBluePlus.adapterState.first;
      
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('BLE Service: Bluetooth is off, attempting to turn on...');
        // On Android, try to turn on Bluetooth
        if (defaultTargetPlatform == TargetPlatform.android) {
          try {
            await FlutterBluePlus.turnOn();
            // Wait a bit for Bluetooth to turn on
            await Future.delayed(const Duration(seconds: 2));
          } catch (e) {
            debugPrint('BLE Service: Could not turn on Bluetooth - $e');
            return;
          }
        } else {
          debugPrint('BLE Service: Please turn on Bluetooth manually');
          return;
        }
      }
      
      // Stop any previous scan
      await FlutterBluePlus.stopScan();
      
      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _discoveredDevices.clear();
        
        for (final result in results) {
          final deviceName = result.device.platformName;
          if (deviceName.isNotEmpty) {
            _discoveredDevices.add(BleDeviceInfo(
              name: deviceName,
              id: result.device.remoteId.str,
              rssi: result.rssi,
              serviceUuids: result.advertisementData.serviceUuids.map((uuid) => uuid.toString()).toList(),
              nativeDevice: result.device,
            ));
          }
        }
        
        _deviceController.add(List.from(_discoveredDevices));
      });
      
      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
      
    } catch (e) {
      debugPrint('BLE Service: Scan error - $e');
    }
  }

  @override
  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  @override
  Future<bool> connect(BleDeviceInfo device) async {
    try {
      final bluetoothDevice = device.nativeDevice;
      if (bluetoothDevice == null) {
        debugPrint('BLE Service: No native device available');
        return false;
      }
      
      // Connect to the device
      await bluetoothDevice.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      
      _connectedDevice = bluetoothDevice;
      
      // Discover services
      final services = await bluetoothDevice.discoverServices();
      
      // Find the target service and characteristic
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              _txCharacteristic = characteristic;
              debugPrint('BLE Service: Found TX characteristic!');
              return true;
            }
          }
        }
      }
      
      // If we didn't find the specific characteristic, try to find any writable one
      // Prioritize WRITE WITH RESPONSE over WRITE WITHOUT RESPONSE for ESP32 compatibility
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            _txCharacteristic = characteristic;
            debugPrint('BLE Service: Using fallback WRITE characteristic: ${characteristic.uuid}');
            return true;
          }
        }
      }
      // Only use writeWithoutResponse as last resort
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.properties.writeWithoutResponse) {
            _txCharacteristic = characteristic;
            debugPrint('BLE Service: Using fallback WRITE_NO_RESPONSE characteristic: ${characteristic.uuid}');
            return true;
          }
        }
      }
      
      debugPrint('BLE Service: Connected but no writable characteristic found');
      return true; // Still connected, just can't write
      
    } catch (e) {
      debugPrint('BLE Service: Connection failed - $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _connectedDevice?.disconnect();
    } catch (e) {
      debugPrint('BLE Service: Disconnect error - $e');
    }
    _connectedDevice = null;
    _txCharacteristic = null;
  }

  @override
  Future<void> sendData(String data) async {
    if (_txCharacteristic == null) {
      debugPrint('BLE Service: No characteristic available for sending');
      return;
    }
    
    // Validate characteristic supports WRITE
    if (!_txCharacteristic!.properties.write) {
      debugPrint('BLE Service: Characteristic does not support WRITE WITH RESPONSE');
      // Fall back to writeWithoutResponse only if write is not supported
      if (_txCharacteristic!.properties.writeWithoutResponse) {
        try {
          final bytes = data.codeUnits;
          await _txCharacteristic!.write(bytes, withoutResponse: true);
          debugPrint('BLE Send (no response): $data');
          return;
        } catch (e) {
          debugPrint('BLE Service: Send failed - $e');
          rethrow;
        }
      }
      throw Exception('Characteristic does not support WRITE');
    }
    
    try {
      final bytes = data.codeUnits;
      // MANDATORY: Use withoutResponse: false for ESP32 compatibility
      await _txCharacteristic!.write(bytes, withoutResponse: false);
      debugPrint('BLE Send: $data');
    } catch (e) {
      debugPrint('BLE Service: Send failed - $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    stopScan();
    disconnect();
    _deviceController.close();
  }
}
