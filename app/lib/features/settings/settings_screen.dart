import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../services/storage.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _themeMode = 'system';
  bool _telemetryEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final storage = await ref.read(storageServiceAsyncProvider.future);
      final themeMode = await storage.getThemeMode();
      final telemetryEnabled = await storage.getTelemetryEnabled();
      
      setState(() {
        _themeMode = themeMode;
        _telemetryEnabled = telemetryEnabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Appearance Section
                _buildSectionHeader('Appearance', PhosphorIcons.palette()),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(PhosphorIcons.moon()),
                        title: const Text('Theme'),
                        subtitle: Text(_getThemeDisplayName(_themeMode)),
                        trailing: Icon(PhosphorIcons.caretRight()),
                        onTap: () => _showThemeDialog(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Privacy Section
                _buildSectionHeader('Privacy', PhosphorIcons.shieldCheck()),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(PhosphorIcons.chartBar()),
                        title: const Text('Anonymous Analytics'),
                        subtitle: const Text('Help improve BetterSaid with usage data'),
                        value: _telemetryEnabled,
                        onChanged: _updateTelemetry,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(PhosphorIcons.trash()),
                        title: const Text('Clear All Data'),
                        subtitle: const Text('Remove all stored room data'),
                        trailing: Icon(PhosphorIcons.caretRight()),
                        onTap: () => _showClearDataDialog(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // About Section
                _buildSectionHeader('About', PhosphorIcons.info()),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(PhosphorIcons.target()),
                        title: const Text('BetterSaid'),
                        subtitle: const Text('Version 1.0.0'),
                        trailing: Icon(PhosphorIcons.caretRight()),
                        onTap: () => _showAboutDialog(),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(PhosphorIcons.shieldCheck()),
                        title: const Text('Privacy Policy'),
                        trailing: Icon(PhosphorIcons.arrowSquareOut()),
                        onTap: () => _launchPrivacyPolicy(),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(PhosphorIcons.fileText()),
                        title: const Text('Terms of Service'),
                        trailing: Icon(PhosphorIcons.arrowSquareOut()),
                        onTap: () => _launchTermsOfService(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Footer
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Anonymous by design',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No accounts • No tracking • Auto-delete',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getThemeDisplayName(String themeMode) {
    switch (themeMode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      case 'system':
      default:
        return 'System';
    }
  }
  
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('System'),
              subtitle: const Text('Follow system setting'),
              value: 'system',
              groupValue: _themeMode,
              onChanged: (value) {
                Navigator.of(context).pop();
                _updateTheme(value!);
              },
            ),
            RadioListTile<String>(
              title: const Text('Light'),
              subtitle: const Text('Light theme'),
              value: 'light',
              groupValue: _themeMode,
              onChanged: (value) {
                Navigator.of(context).pop();
                _updateTheme(value!);
              },
            ),
            RadioListTile<String>(
              title: const Text('Dark'),
              subtitle: const Text('Dark theme'),
              value: 'dark',
              groupValue: _themeMode,
              onChanged: (value) {
                Navigator.of(context).pop();
                _updateTheme(value!);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _updateTheme(String themeMode) async {
    try {
      final storage = await ref.read(storageServiceAsyncProvider.future);
      await storage.setThemeMode(themeMode);
      setState(() => _themeMode = themeMode);
    } catch (e) {
      // Handle error
    }
  }
  
  Future<void> _updateTelemetry(bool enabled) async {
    try {
      final storage = await ref.read(storageServiceAsyncProvider.future);
      await storage.setTelemetryEnabled(enabled);
      setState(() => _telemetryEnabled = enabled);
    } catch (e) {
      // Handle error
    }
  }
  
  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will remove all stored room data including session information and preferences. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _clearAllData() async {
    try {
      final storage = await ref.read(storageServiceAsyncProvider.future);
      await storage.clearAll();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear data: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'BetterSaid',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        PhosphorIcons.target(),
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      children: [
        const Text(
          'Anonymous, Link-Based Fight Mediator\n\n'
          'BetterSaid helps people cool down conflicts with AI-powered rewrites. '
          'Set a goal, paste your heated draft, and get calm, direct, and brief alternatives to copy.\n\n'
          'Anonymous by design • Privacy-first • Auto-delete',
        ),
      ],
    );
  }
  
  void _launchPrivacyPolicy() {
    // In a real app, this would launch the privacy policy URL
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy policy would open here')),
    );
  }
  
  void _launchTermsOfService() {
    // In a real app, this would launch the terms of service URL
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terms of service would open here')),
    );
  }
}
