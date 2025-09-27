import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as models;
import 'package:gamepadvirtual/services/connection_service.dart';
import 'package:gamepadvirtual/widgets/connection_status.dart';
import 'package:gamepadvirtual/screens/gamepad_screen.dart';
import 'package:gamepadvirtual/screens/layout_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ConnectionService _connectionService = ConnectionService();
  models.ConnectionState _connectionState =
      models.ConnectionState.disconnected();
  // MODIFICADO: Removido estado local, usaremos o do _connectionState
  // bool _hasExternalGamepad = false;

  @override
  void initState() {
    super.initState();
    _connectionService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 30),

              // Connection Status
              ConnectionStatusCard(connectionState: _connectionState),
              const SizedBox(height: 20),

              // Connection Options
              _buildConnectionOptions(),
              const SizedBox(height: 20),

              // External Gamepad Status
              _buildExternalGamepadStatus(),
              const SizedBox(height: 30),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.gamepad,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Text(
              'GamePadVirtual',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Transforme seu celular em um gamepad universal',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildConnectionOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Opções de Conexão',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // Bluetooth
            _buildConnectionOption(
              icon: Icons.bluetooth,
              title: 'Bluetooth',
              subtitle: 'Conectar via Bluetooth',
              onTap: _showBluetoothDevices,
            ),
            const SizedBox(height: 12),
            // WiFi Direct
            _buildConnectionOption(
              icon: Icons.wifi,
              title: 'Wi-Fi Direct',
              subtitle: 'Conectar via Wi-Fi Direct (Requer App no PC)',
              onTap: _showWifiDirectOptions,
            ),
            const SizedBox(height: 12),
            // USB
            _buildConnectionOption(
              icon: Icons.usb,
              title: 'USB',
              subtitle: 'Esperando conexão USB (Requer App no PC)',
              onTap: _connectUSB,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalGamepadStatus() {
    // MODIFICADO: Usa o estado de conexão real
    final bool hasExternalGamepad = _connectionState.isExternalGamepad;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.sports_esports,
              color: hasExternalGamepad ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gamepad Externo',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    hasExternalGamepad
                        ? 'Gamepad externo conectado'
                        : 'Nenhum gamepad externo detectado',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: hasExternalGamepad ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _goToGamepad,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text(
              'Iniciar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _goToLayoutSelection,
            child: const Text('Layout do Controle'),
          ),
        ),
      ],
    );
  }

  void _showBluetoothDevices() async {
    final devices = await _connectionService.getBluetoothDevices();

    if (!mounted) return;

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nenhum dispositivo pareado. Abrindo configurações...'),
      ));
      await _connectionService.openBluetoothSettings();
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => _buildBluetoothDevicesList(devices),
    );
  }

  Widget _buildBluetoothDevicesList(List<BluetoothDevice> devices) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dispositivos Bluetooth',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ...devices.map((device) => ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(device.name ?? 'Dispositivo Desconhecido'),
                subtitle: Text(device.address),
                onTap: () {
                  Navigator.pop(context);
                  _connectBluetooth(device);
                },
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                _connectionService.openBluetoothSettings();
              },
              child: const Text('Abrir Configurações Bluetooth'),
            ),
          ),
        ],
      ),
    );
  }

  // MODIFICADO: Exibe aviso sobre necessidade de app no PC.
  void _showWifiDirectOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conexão Wi-Fi Direct'),
        content: const Text(
            'Esta funcionalidade será implementada em futuras versões e necessitará de um programa no computador para funcionar.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _connectBluetooth(BluetoothDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Conectando...'),
          ],
        ),
      ),
    );

    final success = await _connectionService.connectToBluetooth(device);

    if (!mounted) return;
    Navigator.pop(context);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao conectar via Bluetooth')),
      );
    }
  }

  // MODIFICADO: Exibe aviso sobre necessidade de app no PC.
  void _connectUSB() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conexão USB'),
        content: const Text(
            'Conecte o dispositivo via cabo USB. A detecção automática necessitará de um programa no computador para funcionar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _goToGamepad() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GamepadScreen()),
    );
  }

  void _goToLayoutSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LayoutSelectionScreen()),
    );
  }
}