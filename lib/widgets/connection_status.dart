import 'package:flutter/material.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as models;

// =============================================
// WIDGET DE STATUS DE CONEXÃO COMPACTO
// =============================================

/// Widget que exibe o status atual da conexão de forma compacta
/// Usado em barras superiores e espaços reduzidos
class ConnectionStatusWidget extends StatelessWidget {
  final models.ConnectionState connectionState;
  final bool showDetails;

  const ConnectionStatusWidget({
    super.key,
    required this.connectionState,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _getStatusColor().withAlpha(40), // Cor de fundo com transparência
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(), // Borda com cor do status
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Ajusta ao conteúdo
        mainAxisAlignment: MainAxisAlignment.center, // Centraliza conteúdo
        children: [
          // Ícone representativo do tipo de conexão
          Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
            size: 20,
          ),
          const SizedBox(width: 8),
          // Texto descritivo do status
          Flexible(
            child: Text(
              connectionState.statusText,
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: FontWeight.w600,
                fontSize: showDetails ? 14 : 12, // Tamanho adaptável
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis, // Trunca texto longo
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // LÓGICA DE CORES BASEADA NO STATUS
  // =============================================

  /// Retorna a cor apropriada baseada no estado da conexão
  Color _getStatusColor() {
    // Conexão desconectada - vermelho
    if (!connectionState.isConnected) {
      return Colors.red;
    }

    // Conexões ativas - cores por tipo
    switch (connectionState.type) {
      case models.ConnectionType.bluetooth:
        return Colors.blue; // Bluetooth - azul
      case models.ConnectionType.wifiDirect:
        return Colors.orange; // Wi-Fi - laranja
      case models.ConnectionType.usb:
        return Colors.green; // USB - verde
      case models.ConnectionType.externalGamepad:
        return Colors.green; // Gamepad externo - verde
      case models.ConnectionType.none:
        return Colors.red; // Nenhum - vermelho
    }
  }

  // =============================================
  // LÓGICA DE ÍCONES BASEADA NO STATUS
  // =============================================

  /// Retorna o ícone apropriado baseado no tipo de conexão
  IconData _getStatusIcon() {
    // Conexão desconectada
    if (!connectionState.isConnected) {
      return Icons.signal_wifi_off; // Wi-Fi desligado
    }

    // Ícones por tipo de conexão ativa
    switch (connectionState.type) {
      case models.ConnectionType.bluetooth:
        return Icons.bluetooth_connected; // Bluetooth conectado
      case models.ConnectionType.wifiDirect:
        return Icons.wifi; // Wi-Fi
      case models.ConnectionType.usb:
        return Icons.usb; // USB
      case models.ConnectionType.externalGamepad:
        return Icons.sports_esports; // Controle de game
      case models.ConnectionType.none:
        return Icons.signal_wifi_off; // Sem conexão
    }
  }
}

// =============================================
// CARTÃO DE STATUS DE CONEXÃO EXPANDIDO
// =============================================

/// Widget que exibe o status da conexão em formato de cartão
/// Usado para exibir informações mais detalhadas
class ConnectionStatusCard extends StatelessWidget {
  final models.ConnectionState connectionState;

  const ConnectionStatusCard({
    super.key,
    required this.connectionState,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Título da seção
            Text(
              'Status de Conexão',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Widget de status principal
            ConnectionStatusWidget(
              connectionState: connectionState,
              showDetails: true,
            ),
            // Informação adicional - horário da conexão
            if (connectionState.isConnected && connectionState.connectedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Conectado às ${_formatTime(connectionState.connectedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =============================================
  // FORMATAÇÃO DE HORÁRIO
  // =============================================

  /// Formata o horário para exibição amigável
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// =============================================
// DETECTOR DE GAMEPAD EXTERNO (LEGADO)
// =============================================

/// Widget wrapper para detectar gamepads externos
/// [OBSOLETO] - A funcionalidade foi movida para o GamepadInputService
class ExternalGamepadDetector extends StatefulWidget {
  final models.ConnectionState connectionState;
  final Widget child;

  const ExternalGamepadDetector({
    super.key,
    required this.connectionState,
    required this.child,
  });

  @override
  State<ExternalGamepadDetector> createState() =>
      _ExternalGamepadDetectorState();
}

class _ExternalGamepadDetectorState extends State<ExternalGamepadDetector> {
  @override
  Widget build(BuildContext context) {
    // Retorna apenas o filho - a detecção é feita pelo serviço
    // Este widget mantém compatibilidade com código legado
    return widget.child;
  }
}