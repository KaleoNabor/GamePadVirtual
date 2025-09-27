# GamePadVirtual - Arquitetura do Aplicativo

## Visão Geral
GamePadVirtual é um aplicativo que transforma o smartphone em um gamepad universal capaz de conectar com outros dispositivos via Bluetooth, Wi-Fi Direct ou USB.

## Recursos Principais
- Múltiplos layouts de controle (Xbox, PlayStation, Nintendo)
- Feedback tátil com vibração
- Sensores de giroscópio e acelerômetro
- Conectividade múltipla (Bluetooth, Wi-Fi Direct, USB)
- Suporte a gamepad externo
- Layout customizável

## Estrutura de Arquivos

### Modelos de Dados
- `lib/models/gamepad_layout.dart` - Define os layouts dos gamepads
- `lib/models/connection_state.dart` - Estado das conexões
- `lib/models/custom_layout.dart` - Layout personalizado

### Serviços
- `lib/services/connection_service.dart` - Gerencia conexões Bluetooth, Wi-Fi Direct e USB
- `lib/services/vibration_service.dart` - Controla feedback tátil
- `lib/services/sensor_service.dart` - Gerencia giroscópio e acelerômetro
- `lib/services/external_gamepad_service.dart` - Detecta gamepad externo
- `lib/services/storage_service.dart` - Armazena configurações localmente

### Telas
- `lib/screens/home_screen.dart` - Página inicial com opções de conexão
- `lib/screens/gamepad_screen.dart` - Interface do gamepad virtual
- `lib/screens/layout_selection_screen.dart` - Seleção de layout
- `lib/screens/custom_layout_editor_screen.dart` - Editor de layout personalizado

### Widgets
- `lib/widgets/gamepad_buttons/` - Botões específicos de cada layout
- `lib/widgets/analog_stick.dart` - Controle analógico
- `lib/widgets/connection_status.dart` - Indicador de status de conexão
- `lib/widgets/layout_preview.dart` - Preview do layout selecionado

## Fluxo de Navegação
1. **Home** → Status de conexão, opções de conectividade, configurações
2. **Gamepad** → Interface do gamepad ativo (sempre em paisagem)
3. **Layout Selection** → Escolha do layout do gamepad
4. **Custom Layout Editor** → Personalização do layout (sempre em paisagem)

## Dependências Necessárias
- `flutter_bluetooth_serial` - Conexão Bluetooth
- `vibration` - Feedback tátil
- `sensors_plus` - Giroscópio e acelerômetro
- `shared_preferences` - Armazenamento local
- `flutter_gamepad` - Detecção de gamepad externo

## Estados de Conexão
- Desconectado (vermelho)
- Bluetooth conectado
- Wi-Fi Direct conectado
- USB conectado

## Funcionalidades Especiais
- Modo background quando gamepad externo conectado
- Vibração personalizada por botão
- Detecção automática de conexão USB
- Layout totalmente customizável