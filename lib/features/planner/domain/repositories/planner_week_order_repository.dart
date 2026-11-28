abstract interface class PlannerWeekOrderRepository {
  Future<String?> scope(String viewScope);
  Future<Map<String, List<String>>> load(String scope);
  Future<void> save(String scope, Map<String, List<String>> orders);
}
