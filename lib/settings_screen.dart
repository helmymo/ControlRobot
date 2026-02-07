import 'package:flutter/material.dart';
import 'settings_service.dart';

/// Settings screen for configuring command data
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  
  // Joystick direction controllers
  late TextEditingController _forwardController;
  late TextEditingController _backwardController;
  late TextEditingController _leftController;
  late TextEditingController _rightController;
  late TextEditingController _stopController;
  
  // Other controllers
  late TextEditingController _lightsOnController;
  late TextEditingController _lightsOffController;
  late TextEditingController _hornOnController;
  late TextEditingController _hornOffController;
  late TextEditingController _speedController;
  late TextEditingController _gripperOpenController;
  late TextEditingController _gripperCloseController;

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final settings = _settingsService.settings;
    // Joystick directions
    _forwardController = TextEditingController(text: settings.joystickForward);
    _backwardController = TextEditingController(text: settings.joystickBackward);
    _leftController = TextEditingController(text: settings.joystickLeft);
    _rightController = TextEditingController(text: settings.joystickRight);
    _stopController = TextEditingController(text: settings.joystickStop);
    // Other commands
    _lightsOnController = TextEditingController(text: settings.lightsOnCommand);
    _lightsOffController = TextEditingController(text: settings.lightsOffCommand);
    _hornOnController = TextEditingController(text: settings.hornOnCommand);
    _hornOffController = TextEditingController(text: settings.hornOffCommand);
    _speedController = TextEditingController(text: settings.speedCommand);
    _gripperOpenController = TextEditingController(text: settings.gripperOpenCommand);
    _gripperCloseController = TextEditingController(text: settings.gripperCloseCommand);
  }

  @override
  void dispose() {
    _forwardController.dispose();
    _backwardController.dispose();
    _leftController.dispose();
    _rightController.dispose();
    _stopController.dispose();
    _lightsOnController.dispose();
    _lightsOffController.dispose();
    _hornOnController.dispose();
    _hornOffController.dispose();
    _speedController.dispose();
    _gripperOpenController.dispose();
    _gripperCloseController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveSettings() async {
    final newSettings = CommandSettings(
      joystickForward: _forwardController.text,
      joystickBackward: _backwardController.text,
      joystickLeft: _leftController.text,
      joystickRight: _rightController.text,
      joystickStop: _stopController.text,
      lightsOnCommand: _lightsOnController.text,
      lightsOffCommand: _lightsOffController.text,
      hornOnCommand: _hornOnController.text,
      hornOffCommand: _hornOffController.text,
      speedCommand: _speedController.text,
      gripperOpenCommand: _gripperOpenController.text,
      gripperCloseCommand: _gripperCloseController.text,
    );

    await _settingsService.updateSettings(newSettings);
    
    setState(() {
      _hasChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved!'),
          backgroundColor: const Color(0xFF39FF14).withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Reset to Defaults?',
          style: TextStyle(color: Color(0xFF00FFFF)),
        ),
        content: const Text(
          'This will reset all command settings to their default values.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET', style: TextStyle(color: Color(0xFFFF6600))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settingsService.resetToDefaults();
      // Dispose old controllers
      _forwardController.dispose();
      _backwardController.dispose();
      _leftController.dispose();
      _rightController.dispose();
      _stopController.dispose();
      _lightsOnController.dispose();
      _lightsOffController.dispose();
      _hornOnController.dispose();
      _hornOffController.dispose();
      _speedController.dispose();
      _gripperOpenController.dispose();
      _gripperCloseController.dispose();
      // Reinitialize
      _initControllers();
      setState(() {
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings reset to defaults'),
            backgroundColor: const Color(0xFF00FFFF).withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00FFFF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'COMMAND SETTINGS',
          style: TextStyle(
            color: Color(0xFF00FFFF),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save, color: Color(0xFF39FF14)),
              onPressed: _saveSettings,
              tooltip: 'Save Changes',
            ),
          IconButton(
            icon: const Icon(Icons.restore, color: Color(0xFFFF6600)),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to Defaults',
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            
            // JOYSTICK SECTION
            _buildSectionHeader('JOYSTICK DIRECTIONS', Icons.gamepad),
            _buildSettingField(
              controller: _forwardController,
              label: 'Forward Command',
              hint: 'Sent when joystick moves up',
              icon: Icons.arrow_upward,
            ),
            _buildSettingField(
              controller: _backwardController,
              label: 'Backward Command',
              hint: 'Sent when joystick moves down',
              icon: Icons.arrow_downward,
            ),
            _buildSettingField(
              controller: _leftController,
              label: 'Left Command',
              hint: 'Sent when joystick moves left',
              icon: Icons.arrow_back,
            ),
            _buildSettingField(
              controller: _rightController,
              label: 'Right Command',
              hint: 'Sent when joystick moves right',
              icon: Icons.arrow_forward,
            ),
            _buildSettingField(
              controller: _stopController,
              label: 'Stop Command',
              hint: 'Sent when joystick is released',
              icon: Icons.stop_circle_outlined,
            ),
            
            const SizedBox(height: 24),
            _buildSectionHeader('LIGHTS', Icons.lightbulb_outline),
            _buildSettingField(
              controller: _lightsOnController,
              label: 'Lights ON Command',
              hint: 'Command sent when lights turn on',
              icon: Icons.lightbulb,
            ),
            _buildSettingField(
              controller: _lightsOffController,
              label: 'Lights OFF Command',
              hint: 'Command sent when lights turn off',
              icon: Icons.lightbulb_outline,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('HORN', Icons.volume_up),
            _buildSettingField(
              controller: _hornOnController,
              label: 'Horn ON Command',
              hint: 'Command sent when horn pressed',
              icon: Icons.volume_up,
            ),
            _buildSettingField(
              controller: _hornOffController,
              label: 'Horn OFF Command',
              hint: 'Command sent when horn released',
              icon: Icons.volume_off,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('SPEED', Icons.speed),
            _buildSettingField(
              controller: _speedController,
              label: 'Speed Command',
              hint: 'Use {level} as placeholder (1, 2, or 3)',
              icon: Icons.speed,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('GRIPPER', Icons.pan_tool),
            _buildSettingField(
              controller: _gripperOpenController,
              label: 'Gripper OPEN Command',
              hint: 'Command sent when gripper opens',
              icon: Icons.pan_tool,
            ),
            _buildSettingField(
              controller: _gripperCloseController,
              label: 'Gripper CLOSE Command',
              hint: 'Command sent when gripper closes',
              icon: Icons.front_hand,
            ),
            const SizedBox(height: 40),
            _buildSaveButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00FFFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00FFFF).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(0xFF00FFFF),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Customize the data sent to your robot. Each direction sends its own command.',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF39FF14), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF39FF14),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[850]?.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[700]!,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => _markChanged(),
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 14,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey[700],
            fontSize: 12,
          ),
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: _hasChanges
              ? [const Color(0xFF39FF14), const Color(0xFF00AA00)]
              : [Colors.grey[700]!, Colors.grey[800]!],
        ),
        boxShadow: _hasChanges
            ? [
                BoxShadow(
                  color: const Color(0xFF39FF14).withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: _hasChanges ? _saveSettings : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.save,
              color: _hasChanges ? Colors.black : Colors.grey[500],
            ),
            const SizedBox(width: 12),
            Text(
              'SAVE SETTINGS',
              style: TextStyle(
                color: _hasChanges ? Colors.black : Colors.grey[500],
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
