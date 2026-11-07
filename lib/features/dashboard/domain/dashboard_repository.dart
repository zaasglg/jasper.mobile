import 'package:dio/dio.dart';
import '../data/dashboard_layout.dart';

abstract interface class DashboardRepository {
  Future<DashboardLayout> load(String workspaceId, {CancelToken? cancelToken});
  Future<DashboardLayout> save(String workspaceId, DashboardLayout layout);
  Future<List<Map<String, dynamic>>> tasks(
    String workspaceId,
    List<String> projectIds,
  );
  Future<dynamic> widgetData(String workspaceId, String kind);
}

class DashboardException implements Exception {
  const DashboardException(this.message);
  final String message;
  @override
  String toString() => message;
}
