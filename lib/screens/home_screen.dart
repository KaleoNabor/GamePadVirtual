import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as models;
import 'package:gamepadvirtual/screens/layout_selection_screen.dart';
import 'package:gamepadvirtual/screens/gamepad_screen.dart';
import 'package:gamepadvirtual/services/connection_service.dart';
import 'package:gamepadvirtual/widgets/connection_status.dart';

// =============================================
// TELA PRINCIPAL DO APLICATIVO
// =============================================

/// Tela inicial com opções de conexão e navegação
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // =============================================
  // SERVIÇOS E ESTADO
  // =============================================
  
  /// Serviço de gerenciamento de conexões
  final ConnectionService _connectionService = ConnectionService();
  
  /// Estado atual da conexão
  models.ConnectionState _connectionState = models.ConnectionState.disconnected();
  
  /// Timer para verificação periódica da conexão
  Timer? _connectionCheckTimer;

  // =============================================
  // INICIALIZAÇÃO E CICLO DE VIDA
  // =============================================

  @override
  void initState() {
    super.initState();
    
    // Registra observer do ciclo de vida do app
    WidgetsBinding.instance.addObserver(this);
    
    // Escuta mudanças no estado da conexão
    _connectionService.connectionStateStream.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });
    
    // Escuta mensagens do sistema (servidor cheio, etc)
    _connectionService.systemMessageStream.listen(_handleSystemMessage);
    
    // Inicializa com estado atual
    setState(() {
      _connectionState = _connectionService.currentState;
    });

    // Configura verificação periódica da conexão
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _connectionService.checkConnectionStatus();
    });
  }

  @override
  void dispose() {
    // Limpa recursos
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _connectionService.dispose();
    super.dispose();
  }

  // =============================================
  // GERENCIAMENTO DO CICLO DE VIDA DO APP
  // =============================================

  /// Chamado quando o estado do app muda (background/foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Quando o app volta ao foreground, verifica o status da conexão
      _connectionService.checkConnectionStatus();
    }
  }

  // =============================================
  // TRATAMENTO DE MENSAGENS DO SISTEMA
  // =============================================

  /// Processa mensagens recebidas do servidor
  void _handleSystemMessage(String code) {
    // Usa o context diretamente sem async gap
    if (code == 'server_full') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Falha ao conectar: O servidor está cheio (Máx 8 jogadores).'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      });
    }
  }

  // =============================================
  // DIALOGOS E MODAIS INFORMATIVOS
  // =============================================

  /// Exibe informações sobre download do servidor PC
  void _showInfoDialog() {
    final Uri serverUrl = Uri.parse('https://github.com/KaleoNabor/GamePadVirtual-Desktop/releases/');

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
                // Informações sobre o servidor
                const Text(
                  'Para usar este aplicativo, você precisa do servidor rodando no seu PC. '
                  'Baixe a versão mais recente do servidor no link abaixo:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                
                // Link para download
                InkWell(
                  onTap: () => _launchUrl(serverUrl),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(76)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            serverUrl.toString(),
                            style: const TextStyle(
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
                
                // Instruções de uso
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

  /// Lança URL externa com tratamento seguro de contexto
  Future<void> _launchUrl(Uri url) async {
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // CORREÇÃO: Verificação de mounted após async gap
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link.')),
        );
      }
    } catch (e) {
      // CORREÇÃO: Verificação de mounted após async gap
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao abrir o link.')),
      );
    }
  }

  // =============================================
  // DESCOBERTA E SELEÇÃO DE SERVIDORES
  // =============================================

  /// Busca servidores na rede local e exibe modal de seleção
  void _discoverAndShowServers() {
    // Inicia descoberta de servidores
    _connectionService.discoverServers();

    // Exibe modal com servidores encontrados
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
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho do modal
                  Text(
                    'Servidores Encontrados',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecione o PC para conectar. Se nenhum aparecer, verifique se o servidor está rodando e na mesma rede.',
                  ),
                  const SizedBox(height: 16),
                  
                  // Lista de servidores ou indicador de carregamento
                  if (snapshot.connectionState == ConnectionState.waiting || servers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            const Text('Procurando na rede local...'),
                          ],
                        ),
                      ),
                    )
                  else
                    // Lista de servidores encontrados
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: servers.length,
                        itemBuilder: (context, index) {
                          final server = servers[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.computer),
                              title: Text(server.name),
                              subtitle: Text(server.ipAddress.address),
                              onTap: () => _connectToServer(server),
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
      // Para descoberta quando modal é fechado
      _connectionService.stopDiscovery();
    });
  }

  /// Conecta a um servidor com tratamento seguro de contexto
  Future<void> _connectToServer(DiscoveredServer server) async {
    // Fecha o modal primeiro
    Navigator.of(context).pop();
    
    final success = await _connectionService.connectToServer(server);
    
    // CORREÇÃO: Verificação de mounted após async gap
    if (!mounted) return;
    
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Falha ao conectar ao servidor. Verifique se o servidor está rodando e o firewall do PC.',
          ),
        ),
      );
    }
  }

  // =============================================
  // NAVEGAÇÃO ENTRE TELAS
  // =============================================

  /// Navega para a tela do gamepad
  void _goToGamepad() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GamepadScreen()),
    );
  }

  /// Navega para seleção de layout
  void _goToLayoutSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LayoutSelectionScreen()),
    );
  }

  // =============================================
  // WIDGET DE STATUS DE CONEXÃO CENTRALIZADO
  // =============================================

  /// Constroi o widget de status de conexão centralizado
  Widget _buildConnectionStatus() {
    return Container(
      width: double.infinity, // Ocupa toda a largura disponível
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Widget de status principal
          ConnectionStatusWidget(
            connectionState: _connectionState,
            showDetails: true,
          ),
          const SizedBox(height: 8),
          
          // Texto auxiliar quando desconectado
          if (!_connectionState.isConnected)
            const Text(
              'Conecte-se a um servidor para começar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  // =============================================
  // CONSTRUÇÃO DA INTERFACE PRINCIPAL
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GamePadVirtual'),
        actions: [
          // Botão de informações
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
            // =============================================
            // SEÇÃO DE STATUS DE CONEXÃO
            // =============================================
            _buildConnectionStatus(),
            
            const SizedBox(height: 24),
            
            // =============================================
            // BOTÃO PRINCIPAL DE CONEXÃO/DESCONEXÃO
            // =============================================
            if (_connectionState.isConnected)
              // Botão de desconexão (quando conectado)
              ElevatedButton.icon(
                icon: const Icon(Icons.link_off),
                label: const Text('Desconectar'),
                onPressed: () async {
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
              // Botão de conexão (quando desconectado)
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
            
            // Texto informativo sobre tipos de conexão
            if (!_connectionState.isConnected)
              const Text(
                'Use para Wi-Fi ou Ancoragem USB (USB Tethering).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 16),
            const Divider(),

            const SizedBox(height: 16),

            // =============================================
            // BOTÃO DE SELEÇÃO DE LAYOUT
            // =============================================
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

            // =============================================
            // BOTÃO PARA TELA DO CONTROLE
            // =============================================
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

            // =============================================
            // MENSAGEM INFORMATIVA (APENAS DESCONECTADO)
            // =============================================
            if (!_connectionState.isConnected) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(76)),
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
}