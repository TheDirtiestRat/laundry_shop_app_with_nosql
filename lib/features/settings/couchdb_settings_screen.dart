import 'package:flutter/material.dart';

import '../../config/couchdb_settings.dart';
import '../../data/couchdb_client.dart';
import '../../data/laundry_store.dart';

class CouchDbSettingsScreen extends StatefulWidget {
  const CouchDbSettingsScreen({required this.onConnected, super.key});

  final Future<void> Function(LaundryStore store) onConnected;

  @override
  State<CouchDbSettingsScreen> createState() => _CouchDbSettingsScreenState();
}

class _CouchDbSettingsScreenState extends State<CouchDbSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _databaseController = TextEditingController(
    text: CouchDbSettings.defaultDatabase,
  );
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = true;
  bool _isWorking = false;
  bool _hidePassword = true;
  String? _resultMessage;
  bool _resultIsError = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await CouchDbSettings.load();
      if (!mounted) return;
      _baseUrlController.text = settings.baseUrl;
      _databaseController.text = settings.database;
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _resultIsError = true;
        _resultMessage = 'Could not load saved connection settings: $error';
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      CouchDbConfig.validateEndpoint(
        baseUrl: _baseUrlController.text,
        database: _databaseController.text,
      );
      final settings = CouchDbSettings(
        baseUrl: _baseUrlController.text,
        database: _databaseController.text,
      );
      await settings.save();
      _showResult('Connection address and database saved on this computer.');
    } on CouchDbException catch (error) {
      _showResult(error.message, isError: true);
    } catch (error) {
      _showResult('Could not save connection settings: $error', isError: true);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    final client = _createClient();
    if (client == null) return;

    setState(() {
      _isWorking = true;
      _resultMessage = null;
    });
    try {
      final info = await client.getDatabaseInfo();
      if (!mounted) return;
      _showResult(
        'Connected to "${info.name}". '
        '${info.documentCount} document(s) currently in the database.',
      );
    } on CouchDbException catch (error) {
      _showResult(error.message, isError: true);
    } finally {
      client.close();
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _testCrud() async {
    if (!_formKey.currentState!.validate()) return;

    final client = _createClient();
    if (client == null) return;

    setState(() {
      _isWorking = true;
      _resultMessage = null;
    });
    try {
      await client.runCrudSmokeTest();
      if (!mounted) return;
      _showResult(
        'CRUD test passed: created, read, updated, and deleted a temporary '
        'connection-test document.',
      );
    } on CouchDbException catch (error) {
      _showResult(error.message, isError: true);
    } finally {
      client.close();
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _connectToApp() async {
    if (!_formKey.currentState!.validate()) return;

    CouchDbClient? client;
    setState(() {
      _isWorking = true;
      _resultMessage = null;
    });
    try {
      client = _createClient();
      if (client == null) return;
      final info = await client.getDatabaseInfo();
      final store = LaundryStore(client);
      client = null;
      try {
        await store.refresh();
        await CouchDbSettings(
          baseUrl: _baseUrlController.text,
          database: _databaseController.text,
        ).save();
        await widget.onConnected(store);
      } catch (_) {
        store.dispose();
        rethrow;
      }
      if (!mounted) return;
      _showResult(
        'Connected to "${info.name}". Loaded '
        '${store.customers.length} customer(s), ${store.services.length} '
        'service(s), ${store.orders.length} order(s), and '
        '${store.payments.length} payment(s). You can now use the management '
        'screens until the app closes.',
      );
    } on CouchDbException catch (error) {
      _showResult(error.message, isError: true);
    } catch (error) {
      _showResult(
        'Could not connect to the app data store: $error',
        isError: true,
      );
    } finally {
      client?.close();
      if (mounted) setState(() => _isWorking = false);
    }
  }

  CouchDbClient? _createClient() {
    try {
      return CouchDbClient(
        CouchDbConfig(
          baseUrl: _baseUrlController.text,
          database: _databaseController.text,
          username: _usernameController.text,
          password: _passwordController.text,
        ),
      );
    } on CouchDbException catch (error) {
      _showResult(error.message, isError: true);
      return null;
    }
  }

  void _showResult(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _resultMessage = message;
      _resultIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CouchDB connection',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Configure and verify access to your laundry database.',
                style: TextStyle(color: Color(0xFF78869B), fontSize: 14),
              ),
              const SizedBox(height: 22),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                _connectionForm(context),
                const SizedBox(height: 16),
                _securityNotice(),
                if (_resultMessage != null) ...[
                  const SizedBox(height: 16),
                  _resultCard(),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectionForm(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Server settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              _textField(
                controller: _baseUrlController,
                label: 'CouchDB base URL',
                hint: 'https://your-couchdb-host.example',
                icon: Icons.link_rounded,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the CouchDB base URL.'
                    : null,
              ),
              const SizedBox(height: 14),
              _textField(
                controller: _databaseController,
                label: 'Database name',
                hint: CouchDbSettings.defaultDatabase,
                icon: Icons.storage_rounded,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a database name.'
                    : null,
              ),
              const SizedBox(height: 22),
              Text(
                'Restricted CouchDB user',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Credentials are used only for this app session and are not '
                'saved.',
                style: TextStyle(color: Color(0xFF78869B), fontSize: 12),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = [
                    _textField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.person_outline_rounded,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter the restricted user name.'
                          : null,
                    ),
                    _textField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _hidePassword,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter the restricted user password.'
                          : null,
                      suffix: IconButton(
                        tooltip: _hidePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () {
                          setState(() => _hidePassword = !_hidePassword);
                        },
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                        ),
                      ),
                    ),
                  ];
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        fields[0],
                        const SizedBox(height: 14),
                        fields[1],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: 14),
                      Expanded(child: fields[1]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isWorking ? null : _saveSettings,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save address'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isWorking ? null : _testConnection,
                    icon: const Icon(Icons.wifi_tethering_rounded),
                    label: const Text('Test database connection'),
                  ),
                  FilledButton.icon(
                    onPressed: _isWorking ? null : _connectToApp,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Connect and load data'),
                  ),
                  FilledButton.icon(
                    onPressed: _isWorking ? null : _testCrud,
                    icon: _isWorking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fact_check_outlined),
                    label: const Text('Test CRUD operations'),
                  ),
                ],
              ),
              if (_isWorking) ...[
                const SizedBox(height: 12),
                const Text(
                  'Contacting CouchDB…',
                  style: TextStyle(color: Color(0xFF78869B), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFAFBFE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5EAF2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5EAF2)),
        ),
      ),
    );
  }

  Widget _securityNotice() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.shield_outlined,
              color: Color(0xFF4F8FEA),
              size: 22,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Development authentication',
                    style: TextStyle(
                      color: Color(0xFF25334A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Use a CouchDB user restricted to this database, never an '
                    'administrator account. HTTP is accepted only for '
                    'localhost; remote servers must use HTTPS. A production '
                    'desktop app should connect through an authenticated '
                    'backend because client credentials can be extracted.',
                    style: TextStyle(
                      color: Color(0xFF78869B),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard() {
    final color = _resultIsError
        ? const Color(0xFFB63F48)
        : const Color(0xFF258563);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _resultIsError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _resultMessage!,
                style: TextStyle(color: color, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
