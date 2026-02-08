import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// BLE service abstraction
import 'ble_service.dart';
import 'settings_service.dart';
import 'settings_screen.dart';

// ============================================================================
// CONFIGURATION - Change these UUIDs to match your ESP32
// ============================================================================
class BleConfig {
  // Your ESP32's Service UUID (used for filtering)
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  // Your ESP32's Characteristic UUID (the characteristic you write data to)
  static const String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
}

// ============================================================================
// MAIN APP
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load settings before app starts
  await SettingsService().loadSettings();
  
  runApp(const RobotControllerApp());
}

class RobotControllerApp extends StatelessWidget {
  const RobotControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ControlRobot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: const Color(0xFF00FFFF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFFF),
          secondary: Color(0xFF39FF14),
          surface: Color(0xFF1A1A1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
        ),
        textTheme: GoogleFonts.orbitronTextTheme(
          const TextTheme(
            headlineLarge: TextStyle(
              color: Color(0xFF00FFFF),
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            bodyLarge: TextStyle(color: Colors.white70),
            bodyMedium: TextStyle(color: Colors.white60),
          ),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================================
// SPLASH SCREEN - Startup screen with ControlRobot branding
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();

    // Navigate to connection screen after delay
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const ConnectionScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Icon(
                      Icons.smart_toy_outlined,
                      size: 80,
                      color: const Color(0xFF00FFFF),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: Text(
                    'ControlRobot',
                    style: GoogleFonts.orbitron(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00FFFF),
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey[850],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF00FFFF),
                      ),
                      minHeight: 3,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// CONNECTION SCREEN - Scan and connect to ESP32
// ============================================================================
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final BleService _bleService = BleService();
  List<BleDeviceInfo> _scanResults = [];
  bool _isScanning = false;
  BleDeviceInfo? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _bleService.initialize();
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }

  void _startScan() async {
    if (_isScanning) return;

    setState(() {
      _scanResults = [];
      _isScanning = true;
    });

    try {
      await for (final results in _bleService.scan()) {
        if (mounted) {
          setState(() {
            _scanResults = results;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error scanning: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _stopScan() {
    _bleService.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(BleDeviceInfo device) async {
    _showSnackBar('Connecting to ${device.name}...');

    try {
      final connected = await _bleService.connect(device);
      
      if (connected) {
        setState(() {
          _connectedDevice = device;
        });

        _showSnackBar('Connected to ${device.name}!');

        // Navigate to cockpit screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CockpitScreen(bleService: _bleService, deviceName: device.name),
            ),
          ).then((_) {
            // Disconnect when returning from cockpit
            _bleService.disconnect();
            setState(() {
              _connectedDevice = null;
            });
          });
        }
      } else {
        _showSnackBar('Connection failed');
      }
    } catch (e) {
      _showSnackBar('Connection failed: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.grey[850],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ROBOT LINK',
          style: GoogleFonts.orbitron(
            color: const Color(0xFF00FFFF),
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF00FFFF)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[900]!,
              const Color(0xFF0D0D0D),
            ],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Status Indicator
            _buildStatusIndicator(),
            const SizedBox(height: 20),
            // Scan Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildScanButton(),
            ),
            const SizedBox(height: 20),
            // Device List
            Expanded(
              child: _buildDeviceList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[850]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isScanning
              ? const Color(0xFF00FFFF)
              : _connectedDevice != null
                  ? const Color(0xFF39FF14)
                  : Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isScanning
                  ? const Color(0xFF00FFFF)
                  : _connectedDevice != null
                      ? const Color(0xFF39FF14)
                      : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isScanning
                ? 'SCANNING...'
                : _connectedDevice != null
                    ? 'CONNECTED'
                    : 'DISCONNECTED',
            style: GoogleFonts.orbitron(
              color: _isScanning
                  ? const Color(0xFF00FFFF)
                  : _connectedDevice != null
                      ? const Color(0xFF39FF14)
                      : Colors.grey[500],
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: _isScanning
              ? [Colors.grey[700]!, Colors.grey[800]!]
              : [const Color(0xFF00FFFF), const Color(0xFF0088AA)],
        ),
        boxShadow: _isScanning
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF00FFFF).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _isScanning ? _stopScan : _startScan,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isScanning)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              const Icon(Icons.bluetooth_searching, color: Colors.black, size: 22),
            const SizedBox(width: 12),
            Text(
              _isScanning ? 'STOP SCAN' : 'SCAN DEVICES',
              style: GoogleFonts.orbitron(
                color: _isScanning ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isMyEsp(BleDeviceInfo device) {
    // Check by Service UUID first (most reliable)
    if (device.serviceUuids.any((uuid) =>
        uuid.toLowerCase() == BleConfig.serviceUuid.toLowerCase())) {
      return true;
    }

    // Fallback: Check by name
    final name = device.name.toLowerCase();
    return name.contains('esp32') ||
           name.contains('robot') ||
           name.contains('omar');
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.orbitron(
          color: const Color(0xFF00FFFF),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_scanResults.isEmpty && !_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, size: 60, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: GoogleFonts.orbitron(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap SCAN to search for devices',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Separate devices
    final myDevices = _scanResults.where((d) => _isMyEsp(d)).toList();
    final otherDevices = _scanResults.where((d) => !_isMyEsp(d)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (myDevices.isNotEmpty) ...[
          _buildSectionHeader('MY ROBOT'),
          ...myDevices.map((d) => _buildDeviceCard(d)),
        ],

        if (otherDevices.isNotEmpty) ...[
          _buildSectionHeader('OTHER DEVICES'),
          ...otherDevices.map((d) => _buildDeviceCard(d)),
        ],
      ],
    );
  }

  Widget _buildDeviceCard(BleDeviceInfo device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[850]?.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00FFFF).withOpacity(0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF00FFFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bluetooth, color: Color(0xFF00FFFF)),
        ),
        title: Text(
          device.name.isNotEmpty ? device.name : 'Unknown',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          '${device.rssi} dBm',
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        trailing: ElevatedButton(
          onPressed: () => _connectToDevice(device),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF39FF14),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            'LINK',
            style: GoogleFonts.orbitron(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COCKPIT SCREEN - Robot Control Dashboard
// ============================================================================
class CustomButtonData {
  String label;
  String command;

  CustomButtonData({required this.label, required this.command});
}

class CockpitScreen extends StatefulWidget {
  final BleService bleService;
  final String deviceName;

  const CockpitScreen({super.key, required this.bleService, required this.deviceName});

  @override
  State<CockpitScreen> createState() => _CockpitScreenState();
}

class _CockpitScreenState extends State<CockpitScreen> {
  bool _isConnected = true;
  final SettingsService _settingsService = SettingsService();

  // Joystick values
  double _linear = 0.0;
  double _angular = 0.0;

  // Button states
  bool _lightsOn = false;
  int _speedMode = 1;
  bool _gripperOpen = true;

  // Terminal state
  bool _showTerminal = false;
  final List<String> _terminalLogs = [];
  final ScrollController _terminalScrollController = ScrollController();

  // Custom Buttons State
  List<CustomButtonData> _customButtons = [
    CustomButtonData(label: 'BTN 1', command: 'CMD1'),
    CustomButtonData(label: 'BTN 2', command: 'CMD2'),
    CustomButtonData(label: 'BTN 3', command: 'CMD3'),
  ];

  // Throttle timer for joystick (100ms)
  Timer? _sendTimer;
  bool _needsSend = false;

  @override
  void initState() {
    super.initState();
    _startSendTimer();
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    super.dispose();
  }

  void _startSendTimer() {
    // Send joystick data at most every 100ms to avoid flooding
    _sendTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_needsSend) {
        _sendJoystickData();
        _needsSend = false;
      }
    });
  }

  /// Central helper function to write data to BLE characteristic
  Future<void> writeData(String data) async {
    if (!_isConnected) {
      _logToTerminal('Error: Not connected');
      return;
    }
    
    try {
      await widget.bleService.sendData(data);
      _logToTerminal('TX: ${data.trim()}');
    } catch (e) {
      _logToTerminal('Error: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  void _logToTerminal(String message) {
    if (!mounted) return;
    setState(() {
      _terminalLogs.add(message);
      // Keep only last 50 logs
      if (_terminalLogs.length > 50) {
        _terminalLogs.removeAt(0);
      }
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendJoystickData() {
    // Format: M,[linear],[angular]\n
    final data = 'M,${_linear.toStringAsFixed(2)},${_angular.toStringAsFixed(2)}\n';
    writeData(data);
  }

  void _onJoystickMove(double x, double y) {
    // Y is linear (forward/back), X is angular (left/right)
    final newLinear = double.parse((-y).toStringAsFixed(2)); // Invert Y for forward
    final newAngular = double.parse(x.toStringAsFixed(2));

    if ((newLinear - _linear).abs() > 0.05 || (newAngular - _angular).abs() > 0.05) {
      _linear = newLinear;
      _angular = newAngular;
      _needsSend = true;
      setState(() {});
    }
  }

  void _onJoystickEnd() {
    if (_linear != 0.0 || _angular != 0.0) {
      _linear = 0.0;
      _angular = 0.0;
      // Immediately send stop on release
      writeData('M,0,0\n');
      setState(() {});
    }
  }

  // Action buttons
  void _onCustomButtonPressed(int index) {
    HapticFeedback.mediumImpact();
    final btn = _customButtons[index];
    writeData('${btn.command}\n');
  }

  void _onCustomButtonLongPress(int index) {
    HapticFeedback.heavyImpact();
    _showEditButtonDialog(index);
  }

  void _showEditButtonDialog(int index) {
    final btn = _customButtons[index];
    final labelController = TextEditingController(text: btn.label);
    final cmdController = TextEditingController(text: btn.command);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Edit Button ${index + 1}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label', labelStyle: TextStyle(color: Colors.grey)),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: cmdController,
              decoration: const InputDecoration(labelText: 'Command', labelStyle: TextStyle(color: Colors.grey)),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _customButtons[index] = CustomButtonData(
                  label: labelController.text,
                  command: cmdController.text,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFF00FFFF))),
          ),
        ],
      ),
    );
  }

  void _toggleLights() {
    HapticFeedback.lightImpact();
    setState(() {
      _lightsOn = !_lightsOn;
    });
    final settings = _settingsService.settings;
    writeData(_lightsOn ? settings.lightsOnCommand : settings.lightsOffCommand);
  }

  void _cycleSpeedMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _speedMode = (_speedMode % 3) + 1;
    });
    writeData(_settingsService.settings.formatSpeed(_speedMode));
  }

  void _toggleGripper() {
    HapticFeedback.lightImpact();
    setState(() {
      _gripperOpen = !_gripperOpen;
    });
    final settings = _settingsService.settings;
    writeData(_gripperOpen ? settings.gripperOpenCommand : settings.gripperCloseCommand);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00FFFF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'COCKPIT',
          style: GoogleFonts.orbitron(
            color: const Color(0xFF00FFFF),
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        actions: [
        actions: [
          IconButton(
            icon: Icon(_showTerminal ? Icons.terminal : Icons.terminal_outlined, 
              color: _showTerminal ? const Color(0xFF39FF14) : Colors.grey),
            onPressed: () {
              setState(() {
                _showTerminal = !_showTerminal;
              });
            },
          ),
        actions: [
          IconButton(
            icon: Icon(_showTerminal ? Icons.terminal : Icons.terminal_outlined, 
              color: _showTerminal ? const Color(0xFF39FF14) : Colors.grey),
            onPressed: () {
              setState(() {
                _showTerminal = !_showTerminal;
              });
            },
          ),
          _buildConnectionIndicator(),
          const SizedBox(width: 12),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, const Color(0xFF0D0D0D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top action buttons row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildSmallActionButton(
                      icon: _lightsOn ? Icons.lightbulb : Icons.lightbulb_outline,
                      label: 'LIGHTS',
                      isActive: _lightsOn,
                      color: const Color(0xFFFFFF00),
                      onTap: _toggleLights,
                    ),
                    const SizedBox(width: 12),
                    _buildSmallActionButton(
                      icon: Icons.speed,
                      label: 'SPEED $_speedMode',
                      isActive: _speedMode > 1,
                      color: const Color(0xFF39FF14),
                      onTap: _cycleSpeedMode,
                    ),
                    const SizedBox(width: 12),
                    _buildSmallActionButton(
                      icon: _gripperOpen ? Icons.pan_tool : Icons.front_hand,
                      label: 'GRIP',
                      isActive: !_gripperOpen,
                      color: const Color(0xFFFF00FF),
                      onTap: _toggleGripper,
                    ),
                  ],
                ),
              ),
              
              // Main control area with joystick in center
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Joystick readout
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[850]?.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[700]!),
                        ),
                        child: Text(
                          'L: ${_linear.toStringAsFixed(2)}  A: ${_angular.toStringAsFixed(2)}',
                          style: GoogleFonts.sourceCodePro(
                            color: const Color(0xFF00FFFF),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Joystick
                      _buildJoystick(),
                    ],
                  ),
                ),
              ),
              
              // Bottom control buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _buildControlButton(
                          label: _customButtons[i].label,
                          color: const Color(0xFF2196F3),
                          onPressed: () => _onCustomButtonPressed(i),
                          onLongPress: () => _onCustomButtonLongPress(i),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // TERMINAL OVERLAY
              if (_showTerminal)
                Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.black.withOpacity(0.9),
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF39FF14), width: 1)),
                  ),
                  child: ListView.builder(
                    controller: _terminalScrollController,
                    itemCount: _terminalLogs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _terminalLogs[index],
                        style: GoogleFonts.sourceCodePro(
                          color: const Color(0xFF39FF14),
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (_isConnected ? const Color(0xFF39FF14) : Colors.red).withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isConnected ? const Color(0xFF39FF14) : Colors.red,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected ? const Color(0xFF39FF14) : Colors.red,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isConnected ? 'LINKED' : 'LOST',
            style: GoogleFonts.orbitron(
              color: _isConnected ? const Color(0xFF39FF14) : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoystick() {
    const double outerSize = 180;
    const double innerSize = 60;
    const double maxOffset = (outerSize - innerSize) / 2 - 10;

    return GestureDetector(
      onPanUpdate: (details) {
        final center = const Offset(outerSize / 2, outerSize / 2);
        final offset = details.localPosition - center;
        final distance = offset.distance;
        final clampedDistance = distance.clamp(0.0, maxOffset);
        final normalizedOffset = distance > 0 
            ? offset / distance * clampedDistance 
            : Offset.zero;
        
        final x = (normalizedOffset.dx / maxOffset).clamp(-1.0, 1.0);
        final y = (normalizedOffset.dy / maxOffset).clamp(-1.0, 1.0);
        
        _onJoystickMove(x, y);
      },
      onPanEnd: (_) => _onJoystickEnd(),
      child: Container(
        width: outerSize,
        height: outerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[800]!,
              Colors.grey[900]!,
            ],
          ),
          border: Border.all(color: const Color(0xFF00FFFF).withOpacity(0.5), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FFFF).withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Direction arrows
            Positioned(top: 15, child: Icon(Icons.keyboard_arrow_up, size: 24, color: _linear > 0.3 ? const Color(0xFF00FFFF) : Colors.grey[600])),
            Positioned(bottom: 15, child: Icon(Icons.keyboard_arrow_down, size: 24, color: _linear < -0.3 ? const Color(0xFF00FFFF) : Colors.grey[600])),
            Positioned(left: 15, child: Icon(Icons.keyboard_arrow_left, size: 24, color: _angular < -0.3 ? const Color(0xFF00FFFF) : Colors.grey[600])),
            Positioned(right: 15, child: Icon(Icons.keyboard_arrow_right, size: 24, color: _angular > 0.3 ? const Color(0xFF00FFFF) : Colors.grey[600])),
            // Joystick knob
            Transform.translate(
              offset: Offset(_angular * maxOffset, _linear * -maxOffset),
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00FFFF), Color(0xFF0088AA)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FFFF).withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.2) : Colors.grey[850],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? color : Colors.grey[700]!,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: isActive ? color : Colors.grey[500]),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.orbitron(
                  color: isActive ? color : Colors.grey[500],
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
    VoidCallback? onLongPress,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          padding: EdgeInsets.symmetric(vertical: isLarge ? 24 : 16),
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: color.withOpacity(0.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            fontSize: isLarge ? 18 : 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
