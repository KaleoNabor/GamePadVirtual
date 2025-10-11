import 'package:flutter/material.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as models;
import 'package:gamepadvirtual/screens/gamepad_screen.dart';
import 'package:gamepadvirtual/screens/layout_selection_screen.dart';
import 'package:gamepadvirtual/services/connection_service.dart';
import 'package:gamepadvirtual/widgets/connection_status.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ConnectionService _connectionService = ConnectionService();
  models.ConnectionState _connectionState = models.ConnectionState.disconnected();
  
  @override
  void initState() {
    super.initState();
    _connectionService.connectionStateStream.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });
    // Garante que o estado atual seja refletido ao iniciar a tela
    setState(() {
      _connectionState = _connectionService.currentState;
    });
  }

  /// Abre um pop-up para procurar e listar servidores na rede.
  void _discoverAndShowServers() {
    _connectionService.discoverServers(); // Inicia a descoberta

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
                                Navigator.pop(context); // Fecha o pop-up
                                final success = await _connectionService.connectToServer(server);
                                if (!success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Falha ao conectar ao servidor.')),
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
      _connectionService.stopDiscovery(); // Para a descoberta quando o pop-up é fechado
    });
  }

  void _goToGamepad() {
    // Apenas navega para a tela do controle. A conexão é persistente.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GamepadScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('GamePadVirtual'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConnectionStatusCard(connectionState: _connectionState),
          const SizedBox(height: 24),
          
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
          const Text(
            'Use para Wi-Fi ou Ancoragem USB (USB Tethering).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('Conectar via Bluetooth'),
            onTap: () { /* Lógica do Bluetooth aqui */ },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Selecionar Layout do Controle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LayoutSelectionScreen()),
              );
            },
          ),
          const SizedBox(height: 24),

          // BOTÃO RESTAURADO, COMO PEDIDO
          ElevatedButton.icon(
            onPressed: _goToGamepad,
            icon: const Icon(Icons.sports_esports),
            label: const Text('Ir para o Controle'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
    _connectionService.dispose();
    super.dispose();
  }
}