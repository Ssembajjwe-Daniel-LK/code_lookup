// Hour 5: settings page - dark mode switch and server URL.
//
// New concepts:
//  - The settings are owned by CodeLookupApp (the top of the app). This screen
//    gets the current values plus callbacks to change them.
//  - It keeps a LOCAL copy of the switch value, so the switch moves
//    immediately while the change also travels up to the app.
//  - Form + TextFormField + validator: check input before saving.

import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.isDark,
    required this.serverUrl,
    required this.onDarkChanged,
    required this.onServerUrlChanged,
  });

  final bool isDark;
  final String serverUrl;
  final ValueChanged<bool> onDarkChanged;
  final ValueChanged<String> onServerUrlChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isDark = widget.isDark;
  late final _urlController = TextEditingController(text: widget.serverUrl);

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a full URL, e.g. http://127.0.0.1:8010/mcp';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Only http or https';
    }
    return null; // null = valid
  }

  void _saveUrl() {
    // validate() runs every validator in the Form and shows the error texts.
    if (!_formKey.currentState!.validate()) return;
    widget.onServerUrlChanged(_urlController.text.trim());
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Server URL saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dark mode
          SwitchListTile(
            title: const Text('Dark mode'),
            secondary: const Icon(Icons.dark_mode),
            value: _isDark,
            onChanged: (value) {
              setState(() => _isDark = value); // move the switch here
              widget.onDarkChanged(value); // tell the app (saves + redraws)
            },
          ),
          const Divider(height: 32),

          // Server URL
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
              validator: _validateUrl,
              onFieldSubmitted: (_) => _saveUrl(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saveUrl,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Default from --dart-define: http://127.0.0.1:8010/mcp',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
