import 'package:equatable/equatable.dart';

class StorageSummaryContent extends Equatable {
  const StorageSummaryContent({
    this.participantDetails = const {},
    this.keyDecisions = const [],
    this.allEntries = const [],
    this.duration,
  });
  final Map<String, dynamic> participantDetails;
  final List<Map<String, dynamic>> keyDecisions, allEntries;
  final String? duration;
  StorageSummaryContent copyWith({
    Map<String, dynamic>? participantDetails,
    List<Map<String, dynamic>>? keyDecisions,
    List<Map<String, dynamic>>? allEntries,
    String? duration,
  }) => StorageSummaryContent(
    participantDetails: participantDetails ?? this.participantDetails,
    keyDecisions: keyDecisions ?? this.keyDecisions,
    allEntries: allEntries ?? this.allEntries,
    duration: duration ?? this.duration,
  );
  @override
  List<Object?> get props => [
    participantDetails,
    keyDecisions,
    allEntries,
    duration,
  ];
}
