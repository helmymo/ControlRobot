import 'package:shared_preferences/shared_preferences.dart';

/// Model class for command settings
class CommandSettings {
  // Joystick direction commands
  String joystickForward;
  String joystickBackward;
  String joystickLeft;
  String joystickRight;
  String joystickStop;
  
  // Lights commands
  String lightsOnCommand;
  String lightsOffCommand;
  
  // Horn commands
  String hornOnCommand;
  String hornOffCommand;
  
  // Speed command - use {level} as placeholder
  String speedCommand;
  
  // Gripper commands
  String gripperOpenCommand;
  String gripperCloseCommand;

  CommandSettings({
    this.joystickForward = 'F\n',
    this.joystickBackward = 'B\n',
    this.joystickLeft = 'L\n',
    this.joystickRight = 'R\n',
    this.joystickStop = 'S\n',
    this.lightsOnCommand = 'CMD:LIGHTS:ON\n',
    this.lightsOffCommand = 'CMD:LIGHTS:OFF\n',
    this.hornOnCommand = 'CMD:HORN:ON\n',
    this.hornOffCommand = 'CMD:HORN:OFF\n',
    this.speedCommand = 'CMD:SPEED:{level}\n',
    this.gripperOpenCommand = 'CMD:GRIPPER:OPEN\n',
    this.gripperCloseCommand = 'CMD:GRIPPER:CLOSE\n',
  });

  /// Get joystick command based on direction
  /// Returns the appropriate command based on joystick position
  String getJoystickCommand(double x, double y) {
    // Determine direction based on dominant axis
    const double threshold = 0.3;
    
    if (x.abs() < threshold && y.abs() < threshold) {
      return joystickStop;
    }
    
    // Check if movement is more horizontal or vertical
    if (y.abs() >= x.abs()) {
      // Vertical dominant
      if (y > threshold) {
        return joystickForward;
      } else if (y < -threshold) {
        return joystickBackward;
      }
    } else {
      // Horizontal dominant
      if (x > threshold) {
        return joystickRight;
      } else if (x < -threshold) {
        return joystickLeft;
      }
    }
    
    return joystickStop;
  }

  /// Format speed command with actual level
  String formatSpeed(int level) {
    return speedCommand.replaceAll('{level}', level.toString());
  }

  /// Create a copy with optional overrides
  CommandSettings copyWith({
    String? joystickForward,
    String? joystickBackward,
    String? joystickLeft,
    String? joystickRight,
    String? joystickStop,
    String? lightsOnCommand,
    String? lightsOffCommand,
    String? hornOnCommand,
    String? hornOffCommand,
    String? speedCommand,
    String? gripperOpenCommand,
    String? gripperCloseCommand,
  }) {
    return CommandSettings(
      joystickForward: joystickForward ?? this.joystickForward,
      joystickBackward: joystickBackward ?? this.joystickBackward,
      joystickLeft: joystickLeft ?? this.joystickLeft,
      joystickRight: joystickRight ?? this.joystickRight,
      joystickStop: joystickStop ?? this.joystickStop,
      lightsOnCommand: lightsOnCommand ?? this.lightsOnCommand,
      lightsOffCommand: lightsOffCommand ?? this.lightsOffCommand,
      hornOnCommand: hornOnCommand ?? this.hornOnCommand,
      hornOffCommand: hornOffCommand ?? this.hornOffCommand,
      speedCommand: speedCommand ?? this.speedCommand,
      gripperOpenCommand: gripperOpenCommand ?? this.gripperOpenCommand,
      gripperCloseCommand: gripperCloseCommand ?? this.gripperCloseCommand,
    );
  }
}

/// Service for managing command settings with persistence
class SettingsService {
  static const String _keyJoystickForward = 'joystick_forward';
  static const String _keyJoystickBackward = 'joystick_backward';
  static const String _keyJoystickLeft = 'joystick_left';
  static const String _keyJoystickRight = 'joystick_right';
  static const String _keyJoystickStop = 'joystick_stop';
  static const String _keyLightsOn = 'lights_on';
  static const String _keyLightsOff = 'lights_off';
  static const String _keyHornOn = 'horn_on';
  static const String _keyHornOff = 'horn_off';
  static const String _keySpeed = 'speed';
  static const String _keyGripperOpen = 'gripper_open';
  static const String _keyGripperClose = 'gripper_close';

  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  CommandSettings _settings = CommandSettings();
  CommandSettings get settings => _settings;

  /// Load settings from persistent storage
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _settings = CommandSettings(
      joystickForward: prefs.getString(_keyJoystickForward) ?? _settings.joystickForward,
      joystickBackward: prefs.getString(_keyJoystickBackward) ?? _settings.joystickBackward,
      joystickLeft: prefs.getString(_keyJoystickLeft) ?? _settings.joystickLeft,
      joystickRight: prefs.getString(_keyJoystickRight) ?? _settings.joystickRight,
      joystickStop: prefs.getString(_keyJoystickStop) ?? _settings.joystickStop,
      lightsOnCommand: prefs.getString(_keyLightsOn) ?? _settings.lightsOnCommand,
      lightsOffCommand: prefs.getString(_keyLightsOff) ?? _settings.lightsOffCommand,
      hornOnCommand: prefs.getString(_keyHornOn) ?? _settings.hornOnCommand,
      hornOffCommand: prefs.getString(_keyHornOff) ?? _settings.hornOffCommand,
      speedCommand: prefs.getString(_keySpeed) ?? _settings.speedCommand,
      gripperOpenCommand: prefs.getString(_keyGripperOpen) ?? _settings.gripperOpenCommand,
      gripperCloseCommand: prefs.getString(_keyGripperClose) ?? _settings.gripperCloseCommand,
    );
  }

  /// Save current settings to persistent storage
  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_keyJoystickForward, _settings.joystickForward);
    await prefs.setString(_keyJoystickBackward, _settings.joystickBackward);
    await prefs.setString(_keyJoystickLeft, _settings.joystickLeft);
    await prefs.setString(_keyJoystickRight, _settings.joystickRight);
    await prefs.setString(_keyJoystickStop, _settings.joystickStop);
    await prefs.setString(_keyLightsOn, _settings.lightsOnCommand);
    await prefs.setString(_keyLightsOff, _settings.lightsOffCommand);
    await prefs.setString(_keyHornOn, _settings.hornOnCommand);
    await prefs.setString(_keyHornOff, _settings.hornOffCommand);
    await prefs.setString(_keySpeed, _settings.speedCommand);
    await prefs.setString(_keyGripperOpen, _settings.gripperOpenCommand);
    await prefs.setString(_keyGripperClose, _settings.gripperCloseCommand);
  }

  /// Update settings and save
  Future<void> updateSettings(CommandSettings newSettings) async {
    _settings = newSettings;
    await saveSettings();
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    _settings = CommandSettings();
    await saveSettings();
  }
}
