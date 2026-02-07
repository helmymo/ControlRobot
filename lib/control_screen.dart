import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

class ControlScreen extends StatefulWidget {
  final BluetoothDevice device;

  const ControlScreen({super.key, required this.device});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // UUIDs for the ESP32 BLE service and characteristic
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // BLE characteristic for writing and reading
  BluetoothCharacteristic? _targetCharacteristic;

  // Log window data
  final List<String> _logMessages = [];
  final ScrollController _scrollController = ScrollController();

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = true;
  String _statusMessage = "Connecting...";

  // Joystick throttling
  DateTime _lastJoystickWrite = DateTime.now();
  static const Duration _joystickThrottleDuration = Duration(milliseconds: 150);

  // Stream subscription for notifications
  StreamSubscription<List<int>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBLE();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Initialize BLE connection and set up notifications
  Future<void> _initializeBLE() async {
    try {
      // Connect to device if not already connected
      if (!widget.device.isConnected) {
        setState(() {
          _statusMessage = "Connecting to device...";
        });
        await widget.device.connect(timeout: const Duration(seconds: 10));
      }

      setState(() {
        _isConnected = true;
        _statusMessage = "Discovering services...";
      });

      // Discover services
      List<BluetoothService> services = await widget.device.discoverServices();

      // Find the target service and characteristic
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              _targetCharacteristic = characteristic;
              break;
            }
          }
          break;
        }
      }

      if (_targetCharacteristic == null) {
        setState(() {
          _statusMessage = "Characteristic not found!";
          _isConnecting = false;
        });
        _addLog("ERROR: Target characteristic not found");
        return;
      }

      // Enable notifications
      setState(() {
        _statusMessage = "Enabling notifications...";
      });

      await _targetCharacteristic!.setNotifyValue(true);

      // Listen to notifications
      _notificationSubscription = _targetCharacteristic!.onValueReceived.listen(
        (value) {
          String received = utf8.decode(value);
          _addLog("RX: $received");
        },
        onError: (error) {
          _addLog("ERROR: $error");
        },
      );

      setState(() {
        _isConnecting = false;
        _statusMessage = "Connected";
      });

      _addLog("Connected to ${widget.device.platformName}");
      _addLog("Notifications enabled");

    } catch (e) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _statusMessage = "Connection failed: $e";
      });
      _addLog("ERROR: $e");
    }
  }

  /// Add a message to the log window
  void _addLog(String message) {
    setState(() {
      _logMessages.add("[${_formatTime()}] $message");
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Format current time for log entries
  String _formatTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:"
           "${now.minute.toString().padLeft(2, '0')}:"
           "${now.second.toString().padLeft(2, '0')}";
  }

  /// Write data to the BLE characteristic
  Future<void> _writeData(String data) async {
    if (_targetCharacteristic == null) {
      _addLog("ERROR: Not connected");
      return;
    }

    try {
      await _targetCharacteristic!.write(
        utf8.encode(data),
        withoutResponse: false,
      );
      _addLog("TX: $data");
    } catch (e) {
      _addLog("WRITE ERROR: $e");
    }
  }

  /// Handle joystick movement with throttling
  void _onJoystickMove(StickDragDetails details) {
    final now = DateTime.now();
    
    // Throttle: only send data every 150ms
    if (now.difference(_lastJoystickWrite) < _joystickThrottleDuration) {
      return;
    }
    
    _lastJoystickWrite = now;

    // Calculate linear (Y) and angular (X) speeds
    // Y is inverted because up is negative in the joystick
    double linear = -details.y;  // Forward/backward
    double angular = details.x;   // Left/right

    // Round to 2 decimal places
    linear = double.parse(linear.toStringAsFixed(2));
    angular = double.parse(angular.toStringAsFixed(2));

    // Send motor command
    _writeData("M,$linear,$angular");
  }

  /// Handle joystick release - stop motors immediately
  void _onJoystickRelease() {
    _writeData("M,0,0");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          widget.device.platformName.isNotEmpty 
              ? widget.device.platformName 
              : "Control",
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: _isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ],
      ),
      body: _isConnecting
          ? _buildConnectingScreen()
          : _buildControlScreen(),
    );
  }

  /// Build the loading/connecting screen
  Widget _buildConnectingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.cyanAccent,
          ),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the main control screen
  Widget _buildControlScreen() {
    return Column(
      children: [
        // Top: Log Window (Expanded)
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Log header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        "Log Window",
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Clear log button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _logMessages.clear();
                          });
                        },
                        child: const Icon(Icons.delete_outline, color: Colors.white54, size: 18),
                      ),
                    ],
                  ),
                ),
                // Log content
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _logMessages.length,
                    itemBuilder: (context, index) {
                      String msg = _logMessages[index];
                      Color textColor = Colors.white70;
                      
                      if (msg.contains("ERROR")) {
                        textColor = Colors.redAccent;
                      } else if (msg.contains("TX:")) {
                        textColor = Colors.greenAccent;
                      } else if (msg.contains("RX:")) {
                        textColor = Colors.cyanAccent;
                      }

                      return Text(
                        msg,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Middle: Joystick
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Joystick(
            mode: JoystickMode.all,
            base: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
              ),
            ),
            stick: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.cyanAccent,
                    Colors.cyanAccent.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            listener: _onJoystickMove,
            onStickDragEnd: _onJoystickRelease,
          ),
        ),

        // Bottom: Control Buttons
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                label: "LED ON",
                icon: Icons.lightbulb,
                color: Colors.amber,
                onPressed: () => _writeData("L1_ON"),
              ),
              _buildControlButton(
                label: "LED OFF",
                icon: Icons.lightbulb_outline,
                color: Colors.grey,
                onPressed: () => _writeData("L1_OFF"),
              ),
              _buildControlButton(
                label: "STREAM",
                icon: Icons.stream,
                color: Colors.greenAccent,
                onPressed: () => _writeData("BYTE_START"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build a styled control button
  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
