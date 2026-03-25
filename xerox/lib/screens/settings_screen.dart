import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/providers.dart';
import '../services/print_service.dart';
import '../config/app_config.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _wsUrlController;
  late TextEditingController _apiTokenController;
  late TextEditingController _saveDirectoryController;
  List<String> _availablePrinters = [];
  String? _selectedPrinter;
  bool _isLoading = true;
  bool _showToken = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _wsUrlController = TextEditingController(text: settings.wsUrl);
    _apiTokenController = TextEditingController(text: settings.apiToken);
    _saveDirectoryController = TextEditingController(text: settings.saveDirectory);
    _selectedPrinter = settings.defaultPrinter;
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    final printers = await PrintService.getAvailablePrinters();
    setState(() {
      _availablePrinters = printers.map((p) => p.name).toList();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _wsUrlController.dispose();
    _apiTokenController.dispose();
    _saveDirectoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection Settings
                  _buildSectionHeader('Connection', Icons.wifi),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _wsUrlController,
                    decoration: const InputDecoration(
                      labelText: 'WebSocket Server URL',
                      hintText: 'wss://your-space.hf.space/ws/xerox',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setWsUrl(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiTokenController,
                          obscureText: !_showToken,
                          decoration: InputDecoration(
                            labelText: 'API Token',
                            hintText: 'Paste your XEROX_API_KEY here',
                            prefixIcon: const Icon(Icons.key),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _showToken = !_showToken),
                            ),
                          ),
                          onChanged: (value) {
                            ref.read(settingsProvider.notifier).setApiToken(value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        settings.apiToken.isEmpty ? Icons.warning : Icons.check_circle,
                        color: settings.apiToken.isEmpty ? Colors.orange : Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        settings.apiToken.isEmpty
                            ? 'Required for connection'
                            : 'Token configured (${settings.apiToken.length} chars)',
                        style: TextStyle(
                          color: settings.apiToken.isEmpty ? Colors.orange : Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),


                  // Storage Settings
                  _buildSectionHeader('Storage', Icons.folder),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _saveDirectoryController,
                          decoration: const InputDecoration(
                            labelText: 'Save Directory',
                            prefixIcon: Icon(Icons.folder_open),
                            border: OutlineInputBorder(),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Browse'),
                        onPressed: _selectDirectory,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PDFs will be saved to this directory',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),

                  const SizedBox(height: 32),

                  // Printer Settings
                  _buildSectionHeader('Printing', Icons.print),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _availablePrinters.contains(_selectedPrinter) ? _selectedPrinter : null,
                    decoration: const InputDecoration(
                      labelText: 'Default Printer',
                      prefixIcon: Icon(Icons.print),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Show print dialog each time'),
                      ),
                      ..._availablePrinters.map((printer) => DropdownMenuItem(
                            value: printer,
                            child: Text(printer),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedPrinter = value);
                      ref.read(settingsProvider.notifier).updateSettings(
                            settings.copyWith(defaultPrinter: value),
                          );
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Auto-Print'),
                    subtitle: const Text('Automatically print incoming orders'),
                    value: settings.autoPrint,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setAutoPrint(value);
                    },
                  ),

                  const SizedBox(height: 32),

                  // Notification Settings
                  _buildSectionHeader('Notifications', Icons.notifications),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Notification Sound'),
                    subtitle: const Text('Play sound when new order arrives'),
                    value: settings.notificationSound,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).updateSettings(
                            settings.copyWith(notificationSound: value),
                          );
                    },
                  ),

                  const SizedBox(height: 32),

                  // System Settings
                  _buildSectionHeader('System', Icons.computer),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Minimize to System Tray'),
                    subtitle: const Text('Keep app running in background when closed'),
                    value: settings.minimizeToTray,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).updateSettings(
                            settings.copyWith(minimizeToTray: value),
                          );
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Start on System Boot'),
                    subtitle: const Text('Launch app automatically when computer starts'),
                    value: settings.autoStart,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).updateSettings(
                            settings.copyWith(autoStart: value),
                          );
                      // TODO: Actually register/unregister auto-start
                    },
                  ),

                  const SizedBox(height: 32),

                  // About
                  _buildSectionHeader('About', Icons.info),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Version'),
                    trailing: Text(AppConfig.appVersion),
                  ),
                  ListTile(
                    title: const Text('Database Location'),
                    subtitle: Text('${Platform.environment['APPDATA'] ?? '~'}/XeroxManager/'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _selectDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      _saveDirectoryController.text = result;
      ref.read(settingsProvider.notifier).setSaveDirectory(result);
    }
  }
}
