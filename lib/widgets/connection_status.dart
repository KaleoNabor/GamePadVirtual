import 'package:flutter/material.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as models;

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
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              connectionState.statusText,
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: FontWeight.w600,
                fontSize: showDetails ? 14 : 12,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (!connectionState.isConnected) {
      return Colors.red;
    }

    switch (connectionState.type) {
      case models.ConnectionType.bluetooth:
        return Colors.blue;
      case models.ConnectionType.wifiDirect:
        return Colors.orange;
      case models.ConnectionType.usb:
        return Colors.green;
      case models.ConnectionType.externalGamepad:
        return Colors.green;
      case models.ConnectionType.none:
        return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    if (!connectionState.isConnected) {
      return Icons.signal_wifi_off;
    }

    switch (connectionState.type) {
      case models.ConnectionType.bluetooth:
        return Icons.bluetooth_connected;
      case models.ConnectionType.wifiDirect:
        return Icons.wifi;
      case models.ConnectionType.usb:
        return Icons.usb;
      case models.ConnectionType.externalGamepad:
        return Icons.sports_esports;
      case models.ConnectionType.none:
        return Icons.signal_wifi_off;
    }
  }
}

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
            Text(
              'Status de Conexão',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ConnectionStatusWidget(
              connectionState: connectionState,
              showDetails: true,
            ),
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

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}