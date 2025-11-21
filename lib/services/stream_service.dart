import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:gamepadvirtual/services/connection_service.dart';

class StreamService {
  // --- PADRÃO SINGLETON (A BARREIRA) ---
  static final StreamService _instance = StreamService._internal();
  factory StreamService() => _instance;
  StreamService._internal();
  // -------------------------------------

  RTCPeerConnection? _peerConnection;
  // O renderer agora é persistente. Não o recriamos à toa.
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  Function(RTCVideoRenderer)? onStreamAdded;
  Function()? onConnectionLost;

  // Getter seguro para o renderer
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  bool _isInitialized = false;

  // Variável para guardar a trilha de áudio remota
  MediaStreamTrack? _remoteAudioTrack;
  
  // Estado local do áudio (para aplicar assim que a trilha chegar)
  bool _isAudioEnabled = true; 

  final Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan', // Essencial para multitrack (A+V)
  };

  // Timers para monitoramento
  Timer? _connectionMonitorTimer;
  Timer? _streamTimeoutTimer;

  // Inicializa apenas UMA vez
  Future<void> initialize() async {
    if (_isInitialized) return; // Se já iniciou, não faz nada (Barreira ativa)
    
    debugPrint("🎬 [StreamService] Inicializando Renderer Persistente...");
    try {
      await _remoteRenderer.initialize();
      _isInitialized = true;
      debugPrint("✅ [StreamService] Renderer pronto.");
    } catch (e) {
      debugPrint("❌ [StreamService] Erro renderer: $e");
      rethrow;
    }
  }

  // Método para atualizar a preferência (chamado pela UI)
  void setAudioEnabled(bool enabled) {
    _isAudioEnabled = enabled;
    if (_remoteAudioTrack != null) {
      // Isso muta/desmuta o som localmente sem cortar a conexão
      _remoteAudioTrack!.enabled = enabled;
      // O helper Helper.setVolume(0) também funcionaria, mas enabled é mais nativo
      Helper.setVolume(enabled ? 1.0 : 0.0, _remoteAudioTrack!);
    }
    debugPrint("🔊 [StreamService] Áudio ${enabled ? 'ATIVADO' : 'MUTADO'} localmente");
  }

  Future<void> startConnection() async {
    debugPrint("🎬 [WebRTC] Iniciando conexão WebRTC...");
    
    // Garante limpeza antes de começar
    await disposeConnection();

    try {
      debugPrint("🔄 [WebRTC] Criando PeerConnection...");
      _peerConnection = await createPeerConnection(_config);
      debugPrint("✅ [WebRTC] PeerConnection criado com sucesso");

      // ========== CONFIGURAÇÃO DOS LISTENERS ==========
      _peerConnection!.onConnectionState = (state) {
        debugPrint("🔄 [WebRTC] Estado da conexão: $state");
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          debugPrint("❌ [WebRTC] Conexão falhou/desconectou/fechou");
          onConnectionLost?.call();
          disposeConnection();
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          debugPrint("✅ [WebRTC] CONEXÃO ESTABELECIDA COM SUCESSO!");
          _stopStreamTimeoutTimer(); // Para o timeout quando conectar
          _startConnectionMonitoring();
        }
      };

      _peerConnection!.onIceGatheringState = (state) {
        debugPrint("🧊 [WebRTC] Ice Gathering State: $state");
      };

      _peerConnection!.onSignalingState = (state) {
        debugPrint("📡 [WebRTC] Signaling State: $state");
      };

      _peerConnection!.onIceCandidate = (candidate) {
        debugPrint("🧊 [WebRTC] Novo ICE Candidate gerado:");
        debugPrint("   - sdpMid: ${candidate.sdpMid}");
        debugPrint("   - sdpMLineIndex: ${candidate.sdpMLineIndex}");
        debugPrint("   - candidate: ${candidate.candidate?.substring(0, 50)}...");
        
        final msg = {
          'type': 'webrtc_candidate',
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'candidate': candidate.candidate,
        };
        ConnectionService().sendSignalingMessage(msg);
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint("🎥 [WebRTC] Track recebido: ${event.track.kind}");
        
        if (event.track.kind == 'video') {
          debugPrint("📹 [WebRTC] CONFIGURANDO VÍDEO NO RENDERER!");
          _remoteRenderer.srcObject = event.streams[0];
          _stopStreamTimeoutTimer(); // Para o timeout quando receber vídeo
          
          // Aguarda um frame para garantir que o renderer está pronto
          Future.delayed(Duration(milliseconds: 100), () {
            onStreamAdded?.call(_remoteRenderer);
          });
        } 
        else if (event.track.kind == 'audio') {
          debugPrint("🔊 [WebRTC] Faixa de ÁUDIO detectada!");
          _remoteAudioTrack = event.track;
          
          // Aplica a configuração salva imediatamente
          _remoteAudioTrack!.enabled = _isAudioEnabled;
          
          // Garante volume no helper do WebRTC (fix para alguns Androids)
          if (event.streams.isNotEmpty) {
            try {
              final audioTracks = event.streams[0].getAudioTracks();
              if (audioTracks.isNotEmpty) {
                Helper.setVolume(_isAudioEnabled ? 1.0 : 0.0, audioTracks[0]);
              }
            } catch (e) {
              debugPrint("⚠️ [WebRTC] Erro ao configurar volume: $e");
            }
          }
          
          debugPrint("✅ [WebRTC] Áudio configurado: ${_isAudioEnabled ? 'ATIVO' : 'MUTADO'}");
        }
      };

      // ========== SOLICITA STREAM ==========
      debugPrint("📨 [WebRTC] Enviando request_stream...");
      ConnectionService().sendSignalingMessage({'type': 'request_stream'});

      // ========== INICIA TIMEOUT ==========
      _startStreamTimeoutTimer();

      debugPrint("✅ [WebRTC] Conexão inicializada com sucesso");

    } catch (e, stack) {
      debugPrint("❌ [WebRTC] ERRO CRÍTICO na criação do PeerConnection:");
      debugPrint("   - Erro: $e");
      debugPrint("   - Stack: $stack");
      _stopStreamTimeoutTimer();
      rethrow;
    }
  }

  Future<void> handleSignalingMessage(Map<String, dynamic> data) async {
    final type = data['type'];
    debugPrint("\n📨 [Sinalização] Mensagem recebida: $type");

    if (type == 'webrtc_offer') {
      debugPrint("🎯 [Sinalização] OFERTA RECEBIDA - Processando...");
      
      try {
        // 1. Verifica se precisa criar nova conexão
        if (_peerConnection == null) {
          debugPrint("🔄 [Sinalização] PeerConnection nulo, criando novo...");
          await startConnection();
          await Future.delayed(Duration(milliseconds: 300));
        }

        // 2. Configura oferta remota
        final sdp = data['sdp'];
        debugPrint("📝 [Sinalização] Configurando oferta remota...");
        debugPrint("   - Tamanho SDP: ${sdp.length} caracteres");
        
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, 'offer')
        );
        debugPrint("✅ [Sinalização] Oferta remota configurada");

        // 3. Cria resposta
        debugPrint("📝 [Sinalização] Criando answer...");
        final answer = await _peerConnection!.createAnswer();
        debugPrint("✅ [Sinalização] Answer criada:");
        debugPrint("   - Tipo: ${answer.type}");
        debugPrint("   - Tamanho SDP: ${answer.sdp?.length ?? 0} caracteres");
        
        await _peerConnection!.setLocalDescription(answer);
        debugPrint("✅ [Sinalização] Answer configurada localmente");

        // 4. Envia resposta
        ConnectionService().sendSignalingMessage({
          'type': 'webrtc_answer',
          'sdp': answer.sdp,
        });
        debugPrint("📨 [Sinalização] Answer enviada para servidor");

      } catch (e, stack) {
        debugPrint("❌ [Sinalização] ERRO processando oferta:");
        debugPrint("   - Erro: $e");
        debugPrint("   - Stack: $stack");
      }
      
    } else if (type == 'webrtc_candidate') {
      debugPrint("🧊 [Sinalização] Processando ICE candidate remoto...");
      if (_peerConnection != null) {
        try {
          await _peerConnection!.addCandidate(RTCIceCandidate(
            data['candidate'] ?? '',
            data['sdpMid'] ?? '',
            data['sdpMLineIndex'] ?? 0,
          ));
          debugPrint("✅ [Sinalização] ICE candidate remoto adicionado");
        } catch (e) {
          debugPrint("⚠️ [Sinalização] Erro ao adicionar ICE candidate: $e");
        }
      } else {
        debugPrint("⚠️ [Sinalização] PeerConnection nulo, ignorando candidate");
      }
    } else {
      debugPrint("⚠️ [Sinalização] Tipo de mensagem desconhecido: $type");
      debugPrint("   - Conteúdo: $data");
    }
  }

  // ========== TIMEOUT PARA STREAM ==========
  void _startStreamTimeoutTimer() {
    _stopStreamTimeoutTimer();
    _streamTimeoutTimer = Timer(Duration(seconds: 15), () {
      debugPrint("⏰ [TIMEOUT] Stream não recebido em 15 segundos!");
      if (_peerConnection != null && _remoteRenderer.srcObject == null) {
        debugPrint("🔄 [TIMEOUT] Reiniciando conexão...");
        restartConnection();
      }
    });
  }

  void _stopStreamTimeoutTimer() {
    _streamTimeoutTimer?.cancel();
    _streamTimeoutTimer = null;
  }

  // ========== MONITORAMENTO DE CONEXÃO ==========
  void _startConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_peerConnection == null) {
        timer.cancel();
        return;
      }
      
      final state = _peerConnection!.connectionState;
      debugPrint("📊 [Monitor] Estado da conexão: $state");
      
      // Se a conexão estiver falha, força reinício
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        debugPrint("⚠️ [Monitor] Conexão problemática detectada, considerando reinício...");
        timer.cancel();
        onConnectionLost?.call();
      }
    });
  }

  void _stopConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
  }

  // ========== GERENCIAMENTO DE CONEXÃO ==========
  Future<void> disposeConnection() async {
    debugPrint("🧹 [StreamService] Limpando conexão P2P...");
    _stopConnectionMonitoring();
    _stopStreamTimeoutTimer();
    
    if (_peerConnection != null) {
      debugPrint("🔌 [StreamService] Fechando PeerConnection...");
      // Remove listeners
      _peerConnection!.onConnectionState = null;
      _peerConnection!.onTrack = null;
      _peerConnection!.onIceCandidate = null;
      _peerConnection!.onIceGatheringState = null;
      _peerConnection!.onSignalingState = null;
      
      try {
        await _peerConnection!.close();
        debugPrint("✅ [StreamService] PeerConnection fechado");
      } catch (e) {
        debugPrint("⚠️ [StreamService] Erro ao fechar PeerConnection: $e");
      }
      
      _peerConnection = null;
    }
    
    // Limpa as trilhas remotas
    _remoteAudioTrack = null;
    
    // ATENÇÃO: NÃO limpamos o srcObject do renderer aqui se quisermos manter o último frame
    // ou limpamos apenas se quisermos tela preta.
    // Para estabilidade, vamos limpar, mas o renderer em si continua inicializado.
    _remoteRenderer.srcObject = null; 
    debugPrint("✅ [StreamService] Stream removido do renderer");
  }

  Future<void> restartConnection() async {
    debugPrint("🔄 [StreamService] Reiniciando conexão...");
    await disposeConnection();
    await Future.delayed(Duration(milliseconds: 1000));
    await startConnection();
  }

  // ========== MÉTODOS PÚBLICOS ==========
  Future<void> stopStream() async {
    debugPrint("⏹️ [StreamService] Parando stream...");
    await disposeConnection();
    ConnectionService().sendSignalingMessage({'type': 'stop_stream'});
  }

  // Método para matar tudo DE VERDADE (só quando fechar o app)
  void disposeFull() {
    debugPrint("🗑️ [StreamService] Dispose completo");
    disposeConnection();
    _stopConnectionMonitoring();
    _stopStreamTimeoutTimer();
    _remoteRenderer.dispose();
    _isInitialized = false;
  }

  void dispose() {
    debugPrint("⚠️ [StreamService] Dispose normal chamado (usando disposeFull para limpeza total)");
    disposeFull();
  }

  // ========== GETTERS PARA STATUS ==========
  bool get isConnected {
    final connected = _peerConnection != null && 
           _peerConnection!.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
    return connected;
  }

  bool get hasVideoStream {
    return _remoteRenderer.srcObject != null;
  }

  bool get hasAudioStream {
    return _remoteAudioTrack != null;
  }

  bool get isAudioEnabled => _isAudioEnabled;

  bool get isRendererReady {
    return _remoteRenderer.videoHeight != null;
  }

  bool get isInitialized => _isInitialized;

  RTCPeerConnectionState? get connectionState {
    return _peerConnection?.connectionState;
  }

  // ========== MÉTODOS DE DEBUG ==========
  void printDebugInfo() {
    debugPrint("\n=== 🔍 DEBUG STREAM SERVICE ===");
    debugPrint("Singleton Instance: $_instance");
    debugPrint("Is Initialized: $_isInitialized");
    debugPrint("PeerConnection: ${_peerConnection != null ? 'EXISTE' : 'NULO'}");
    debugPrint("Connection State: ${_peerConnection?.connectionState}");
    debugPrint("Signaling State: ${_peerConnection?.signalingState}");
    debugPrint("Ice Gathering State: ${_peerConnection?.iceGatheringState}");
    debugPrint("Ice Connection State: ${_peerConnection?.iceConnectionState}");
    debugPrint("Renderer srcObject: ${_remoteRenderer.srcObject != null ? 'EXISTE' : 'NULO'}");
    debugPrint("Video Width: ${_remoteRenderer.videoWidth}");
    debugPrint("Video Height: ${_remoteRenderer.videoHeight}");
    debugPrint("Has Video Stream: $hasVideoStream");
    debugPrint("Has Audio Stream: $hasAudioStream");
    debugPrint("Is Audio Enabled: $_isAudioEnabled");
    debugPrint("Is Renderer Ready: $isRendererReady");
    debugPrint("================================\n");
  }

  Map<String, dynamic> get streamInfo {
    return {
      'isSingleton': true,
      'isInitialized': _isInitialized,
      'peerConnectionExists': _peerConnection != null,
      'connectionState': _peerConnection?.connectionState?.toString(),
      'signalingState': _peerConnection?.signalingState?.toString(),
      'iceConnectionState': _peerConnection?.iceConnectionState?.toString(),
      'hasVideoStream': hasVideoStream,
      'hasAudioStream': hasAudioStream,
      'isAudioEnabled': _isAudioEnabled,
      'videoWidth': _remoteRenderer.videoWidth,
      'videoHeight': _remoteRenderer.videoHeight,
      'isRendererReady': isRendererReady,
    };
  }

  // Método para verificar se está processando
  bool get isProcessing {
    return _peerConnection != null && 
           (_peerConnection!.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnecting ||
            _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer ||
            _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateHaveRemoteOffer);
  }
}