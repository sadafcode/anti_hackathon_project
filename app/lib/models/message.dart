import 'provider_model.dart';

enum MessageType { user, agent, reasoning, providerCard }

class Message {
  final String id;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final ProviderModel? provider;
  final String? serviceType;
  final String? locationHint;

  Message({
    required this.id,
    required this.text,
    required this.type,
    DateTime? timestamp,
    this.provider,
    this.serviceType,
    this.locationHint,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Message.user(String text) => Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        type: MessageType.user,
      );

  factory Message.agent(String text) => Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        type: MessageType.agent,
      );

  factory Message.reasoning({
    required String serviceType,
    required String locationHint,
    required ProviderModel topProvider,
  }) =>
      Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        type: MessageType.reasoning,
        serviceType: serviceType,
        locationHint: locationHint,
        provider: topProvider,
      );

  factory Message.providerCard(ProviderModel provider) => Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        type: MessageType.providerCard,
        provider: provider,
      );
}
