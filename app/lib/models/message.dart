import 'provider_model.dart';
import 'pricing_model.dart';

enum MessageType { user, agent, reasoning, providerCard, contract }

class Message {
  final String id;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final ProviderModel? provider;
  final String? serviceType;
  final String? locationHint;
  final String? requestedDatetime; // ISO string for availability day check
  final PricingModel? pricing;
  final String? contractId;

  Message({
    required this.id,
    required this.text,
    required this.type,
    DateTime? timestamp,
    this.provider,
    this.serviceType,
    this.locationHint,
    this.requestedDatetime,
    this.pricing,
    this.contractId,
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

  factory Message.providerCard(ProviderModel provider, {String? requestedDatetime}) => Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        type: MessageType.providerCard,
        provider: provider,
        requestedDatetime: requestedDatetime,
      );

  factory Message.contract({
    required PricingModel pricing,
    required String contractId,
    required ProviderModel provider,
  }) => Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        type: MessageType.contract,
        provider: provider,
        pricing: pricing,
        contractId: contractId,
      );
}
