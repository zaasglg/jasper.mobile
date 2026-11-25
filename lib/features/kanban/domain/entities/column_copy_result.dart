import 'package:equatable/equatable.dart';

enum ColumnCopyStatus {
  idle,
  submitting,
  success,
  failure,
  forbidden,
  stale,
  uncertain,
  cancelled,
}

class ColumnCopyResult extends Equatable {
  const ColumnCopyResult(this.status, {this.columnId, this.message});
  final ColumnCopyStatus status;
  final String? columnId;
  final String? message;
  @override
  List<Object?> get props => [status, columnId, message];
}
