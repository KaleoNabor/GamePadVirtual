import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as models;
import 'package:gamepadvirtual/services/connection_service.dart';
import 'package:gamepadvirtual/widgets/connection_status.dart';
import 'package:gamepadvirtual/screens/gamepad_screen.dart';
import 'package:gamepadvirtual/screens/layout_selection_screen.dart';
import 'package:gamepadvirtual/services/gamepad_input_service.dart';
import 'package:gamepadvirtual/services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // SERVICES
  final GamepadInputService _gamepadInputService = GamepadInputService();
  final ConnectionService _connectionService = ConnectionService();
  final StorageService _storageService = StorageService();
  // STATE VARIABLES
  // Estado da conexão com o PC (BT/USB/WiFi)
  models.ConnectionState _connectionState = models.ConnectionState.disconnected();
  // Estado do gamepad externo conectado ao celular
  models.ConnectionState _externalGamepadState = models.ConnectionState.disconnected();

  @override
  void initState() {
    super.initState();
    // Garante que o serviço de detecção de gamepad externo seja inicializado
    _gamepadInputService.initialize();

    // 1. Ouve o estado da conexão com o PC (Virtual Gamepad)
    _connectionService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() => _connectionState = state);
      }
      // NOVO: Navega para a tela de controle quando a conexão é estabelecida.
      _goToGamepadIfConnected(state);
    });

    // 2. Ouve o estado da conexão com o Gamepad Externo
    _gamepadInputService.connectionStream.listen((state) {
      if (mounted) {
        setState(() => _externalGamepadState = state);
      }
    });

    // 3. Ouve o status do serviço (usado para detectar se o serviço foi parado pela notificação)
    _gamepadInputService.serviceStatusStream.listen((status) {
      if (status == "STOPPED" && _connectionService.currentState.isConnected) {
        // Se o serviço for parado (via notificação) enquanto o controle virtual está ativo,
        // o ConnectionService deve ser notificado para atualizar o estado no app.
        _connectionService.disconnect();
        // Nota: O stopGamepadService() em Dart foi chamado, o que invocou a parada
        // no Kotlin e, em seguida, o onDestroy enviou este status "STOPPED".
      }
    });
    
    // NOVO: Checa o estado da conexão logo no início.
    // Isso é crucial para o requisito de voltar para a GamepadScreen ao clicar na notificação
    // e o app ser reativado.
    _goToGamepadIfConnected(_connectionService.currentState);
  }

  // NOVO: Função para redirecionar para GamepadScreen
  void _goToGamepadIfConnected(models.ConnectionState state) {
  if (state.isConnected && !state.isExternalGamepad) {
    WidgetsBinding.instance.addPostFrameCallback((_) async { // Adicione 'async' aqui
      if (ModalRoute.of(context)?.settings.name != '/gamepad') {
        // Primeiro, lemos a configuração salva
        final bool hapticsOn = await _storageService.isHapticFeedbackEnabled();

        // Só navegamos se o widget ainda estiver montado
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const GamepadScreen(),
            settings: const RouteSettings(name: '/gamepad'),
          ),
        );
        // Agora, passamos a configuração lida ao iniciar o serviço
        _gamepadInputService.startGamepadService(hapticsEnabled: hapticsOn);
      }
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GamePadVirtual'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status do Gamepad Virtual (PC)
              ConnectionStatusCard(connectionState: _connectionState),
              const SizedBox(height: 16),
              
              // Status do Gamepad Externo (Celular)
              if (_externalGamepadState.isConnected) ...[
                ConnectionStatusCard(connectionState: _externalGamepadState),
                const SizedBox(height: 16),
              ],
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conexão com o PC',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      
                      // Opções de Conexão
                      ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: const Text('Bluetooth'),
                        subtitle: const Text('Conecte-se a um dispositivo pareado.'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _openBluetoothConnection(context),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.usb),
                        title: const Text('USB'),
                        subtitle: const Text('Conexão via cabo USB.'),
                        trailing: const Icon(Icons.info_outline, size: 16),
                        onTap: _connectUSB,
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.wifi),
                        title: const Text('Wi-Fi Direct'),
                        subtitle: const Text('Conexão direta de alta velocidade.'),
                        trailing: const Icon(Icons.info_outline, size: 16),
                        onTap: () { /* Implementar lógica Wi-Fi Direct */ },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botão Selecionar Layout
              ElevatedButton.icon(
                onPressed: _goToLayoutSelection,
                icon: const Icon(Icons.grid_view),
                label: const Text('Selecionar Layout'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 32),
              
              // Botão Ir para o Gamepad
              ElevatedButton.icon(
                onPressed: _goToGamepad,
                icon: const Icon(Icons.sports_esports),
                label: const Text('Ir para o Controle'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MÉTODOS AUXILIARES ---

  void _openBluetoothConnection(BuildContext context) async {
    
    final List<BluetoothDevice> bondedDevices =
        await _connectionService.getPairedDevices();

    if (!mounted) return;

    if (bondedDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Nenhum dispositivo Bluetooth pareado encontrado. Certifique-se de parear com o PC.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: bondedDevices.length,
          itemBuilder: (context, index) {
            final device = bondedDevices[index];
            return ListTile(
              title: Text(device.name ?? 'Dispositivo Desconhecido'),
              subtitle: Text(device.address),
              leading: const Icon(Icons.bluetooth_connected),
              onTap: () {
                Navigator.pop(context);
                _connectBluetooth(device);
              },
            );
          },
        );
      },
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
    // Se for sucesso, o listener em initState (_goToGamepadIfConnected) cuida da navegação.
  }

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
    // Navegação manual (se não estiver conectado)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GamepadScreen(),
        settings: const RouteSettings(name: '/gamepad'),
      ),
    );
  }

  void _goToLayoutSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LayoutSelectionScreen()),
    );
  }
}