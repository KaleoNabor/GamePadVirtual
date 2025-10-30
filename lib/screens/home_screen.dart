import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as models;
import 'package:gamepadvirtual/screens/gamepad_screen.dart';
import 'package:gamepadvirtual/screens/layout_selection_screen.dart';
import 'package:gamepadvirtual/services/connection_service.dart';
import 'package:gamepadvirtual/widgets/connection_status.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ConnectionService _connectionService = ConnectionService();
  models.ConnectionState _connectionState = models.ConnectionState.disconnected();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectionService.connectionStateStream.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });
    setState(() {
      _connectionState = _connectionService.currentState;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      if (_connectionState.isConnected) {
        _connectionService.sendDisconnectSignal();
      }
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Onde baixar o Servidor?'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Para usar este aplicativo, você precisa do servidor rodando no seu PC. '
                  'Baixe a versão mais recente do servidor no link abaixo:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    // Aqui você pode adicionar a lógica para abrir o link
                    // Por exemplo: launchUrl(Uri.parse('https://github.com/seu-usuario/gamepad-virtual-server'));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'https://github.com/seu-usuario/gamepad-virtual-server',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Instruções:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. Baixe e execute o servidor no PC\n'
                  '2. Conecte PC e celular na mesma rede\n'
                  '3. Use este app para conectar e jogar',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _discoverAndShowServers() {
    _connectionService.discoverServers();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StreamBuilder<List<DiscoveredServer>>(
          stream: _connectionService.discoveredServersStream,
          initialData: const [],
          builder: (context, snapshot) {
            final servers = snapshot.data ?? [];
            return Container(
              height: MediaQuery.of(context).size.height * 0.4,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Servidores Encontrados', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Selecione o PC para conectar. Se nenhum aparecer, verifique se o servidor está rodando e na mesma rede.'),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting || servers.isEmpty)
                    const Expanded(child: Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Procurando na rede local...'),
                      ],
                    )))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: servers.length,
                        itemBuilder: (context, index) {
                          final server = servers[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.computer),
                              title: Text(server.name),
                              subtitle: Text(server.ipAddress.address),
                              onTap: () async {
                                Navigator.pop(context);
                                final success = await _connectionService.connectToServer(server);
                                
                                if (!mounted) return;
                                
                                if (!success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Falha ao conectar ao servidor. Verifique se o servidor está rodando e o firewall do PC.')),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _connectionService.stopDiscovery();
    });
  }

  void _showBluetoothConnectionDialog() async {
    var scanPermission = await Permission.bluetoothScan.request();
    var connectPermission = await Permission.bluetoothConnect.request();

    if (scanPermission.isDenied || connectPermission.isDenied) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissões de Bluetooth são necessárias para encontrar o servidor.'))
      );
      }
      return;
    }
    
    _connectionService.discoverAllBluetoothDevices();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StreamBuilder<List<DiscoveredBluetoothDevice>>(
          stream: _connectionService.unifiedBluetoothDevicesStream,
          initialData: const [],
          builder: (context, snapshot) {
            final devices = snapshot.data ?? [];
            return Container(
              height: MediaQuery.of(context).size.height * 0.4,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dispositivos Bluetooth Encontrados', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Selecione o seu PC. Dispositivos BLE são recomendados para menor latência.'),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting && devices.isEmpty)
                    const Expanded(child: Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [ 
                        CircularProgressIndicator(), 
                        SizedBox(height: 16), 
                        Text('Procurando dispositivos...'), 
                      ],
                    )))
                  else if (devices.isEmpty)
                    const Expanded(child: Center(child: Text('Nenhum dispositivo encontrado.')))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                device.type == DiscoveredDeviceType.ble
                                  ? Icons.bluetooth_searching 
                                  : Icons.bluetooth_connected,
                                color: device.type == DiscoveredDeviceType.ble
                                  ? Colors.blue 
                                  : Colors.grey,
                              ),
                              title: Text(device.name),
                              subtitle: Text(device.address),
                              trailing: device.type == DiscoveredDeviceType.ble
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: const Text(
                                      "Recomendado",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                              onTap: () async {
                                Navigator.pop(context);
                                final success = await _connectionService.connectToBluetoothDevice(device);
                                
                                if (!mounted) return;
                                
                                if (!success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Falha ao conectar ao dispositivo. Verifique se o servidor está rodando e o firewall do PC.')),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _connectionService.stopAllBluetoothDiscovery();
    });
  }

  void _listAndConnectPairedDevices() async {
    var connectPermission = await Permission.bluetoothConnect.request();
    if (connectPermission.isDenied) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de conexão Bluetooth é necessária.'))
      );
      }
      return;
    }
    
    final List<BluetoothDevice> pairedDevices = await _connectionService.getPairedDevices();

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dispositivos Pareados', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Selecione o seu PC. Se ele não aparecer, pareie-o primeiro nas configurações de Bluetooth do seu celular.'),
              const SizedBox(height: 16),
              if (pairedDevices.isEmpty)
                const Expanded(child: Center(child: Text('Nenhum dispositivo pareado encontrado.')))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: pairedDevices.length,
                    itemBuilder: (context, index) {
                      final device = pairedDevices[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.computer),
                          title: Text(device.name ?? "Dispositivo sem nome"),
                          subtitle: Text(device.address),
                          onTap: () async {
                            Navigator.pop(context);
                            final success = await _connectionService.connectToClassicBluetooth(device);
                            
                            if (!mounted) return;

                            if (!success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Falha ao conectar. Verifique se o servidor está rodando e o firewall do PC.')),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showBluetoothOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.bluetooth_searching, color: Colors.blue),
                title: const Text('Procurar Dispositivos BLE'),
                subtitle: const Text('Recomendado, menor latência.'),
                onTap: () {
                  Navigator.pop(context);
                  _scanAndShowBleDevices();
                },
              ),
              ListTile(
                leading: const Icon(Icons.bluetooth_connected, color: Colors.grey),
                title: const Text('Conectar a Dispositivo Pareado'),
                subtitle: const Text('Modo de compatibilidade (Clássico).'),
                onTap: () {
                  Navigator.pop(context);
                  _listAndConnectPairedDevices();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _scanAndShowBleDevices() async {
    var scanPermission = await Permission.bluetoothScan.request();
    var connectPermission = await Permission.bluetoothConnect.request();

    if (scanPermission.isDenied || connectPermission.isDenied) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissões de Bluetooth são necessárias para encontrar o servidor.'))
      );
      }
      return;
    }

    _connectionService.scanForBleDevices();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StreamBuilder<List<DiscoveredBluetoothDevice>>(
          stream: _connectionService.discoveredBleDevicesStream,
          initialData: const [],
          builder: (context, snapshot) {
            final devices = snapshot.data ?? [];
            return Container(
              height: MediaQuery.of(context).size.height * 0.4,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Servidores Bluetooth LE Encontrados', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting && devices.isEmpty)
                    const Expanded(child: Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [ 
                        CircularProgressIndicator(), 
                        SizedBox(height: 16), 
                        Text('Procurando servidores...'), 
                      ],
                    )))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.bluetooth_searching),
                              title: Text(device.name.isNotEmpty ? device.name : "Dispositivo Desconhecido"),
                              subtitle: Text(device.id),
                              onTap: () async {
                                Navigator.pop(context);
                                final success = await _connectionService.connectToBleDevice(device.underlyingDevice);
                                
                                if (!mounted) return;
                                
                                if (!success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Falha ao conectar ao servidor BLE. Verifique se o servidor está rodando e o firewall do PC.')),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _connectionService.stopBleScan();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GamePadVirtual'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Informações do Servidor',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConnectionStatusCard(connectionState: _connectionState),
            const SizedBox(height: 24),
            
            if (_connectionState.isConnected)
              ElevatedButton.icon(
                icon: const Icon(Icons.link_off),
                label: const Text('Desconectar'),
                onPressed: () async {
                  await _connectionService.sendDisconnectSignal();
                  await _connectionService.disconnect();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.wifi_tethering_rounded),
                label: const Text('Conectar na Rede'),
                onPressed: _discoverAndShowServers,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            
            const SizedBox(height: 8),
            if (!_connectionState.isConnected)
              const Text(
                'Use para Wi-Fi ou Ancoragem USB (USB Tethering).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 16),

            // Botão Bluetooth - Substituído ListTile por ElevatedButton
            ElevatedButton.icon(
              icon: Icon(Icons.bluetooth, color: Theme.of(context).colorScheme.onPrimary),
              label: const Text('Conectar via Bluetooth'),
              onPressed: _connectionState.isConnected ? null : _showBluetoothConnectionDialog,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            if (!_connectionState.isConnected)
              const Text(
                'Busca automática por dispositivos BLE e pareados.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),

            const SizedBox(height: 16),
            const Divider(),

            const SizedBox(height: 16),

            // Botão Layout - Substituído ListTile por OutlinedButton
            OutlinedButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('Selecionar Layout do Controle'),
              onPressed: _goToLayoutSelection,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 16),

            // Botão Ir para Controle - Com cor secundária
            ElevatedButton.icon(
              onPressed: _goToGamepad,
              icon: const Icon(Icons.sports_esports),
              label: const Text('Ir para o Controle'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
            ),

            if (!_connectionState.isConnected) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade600),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Você pode ir para a tela de controle para testar o layout mesmo sem conexão.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionService.dispose();
    super.dispose();
  }
}