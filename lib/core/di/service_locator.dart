import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../network/dio_factory.dart';
import '../storage/auth_token_storage.dart';
import '../storage/workspace_selection_storage.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/projects/data/repositories/project_repository_impl.dart';
import '../../features/projects/domain/repositories/project_repository.dart';
import '../../features/projects/presentation/cubit/projects_cubit.dart';
import '../../features/workspaces/data/repositories/workspace_repository_impl.dart';
import '../../features/workspaces/domain/repositories/workspace_repository.dart';
import '../../features/workspaces/presentation/cubit/workspace_cubit.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // Core
  sl.registerLazySingleton<FlutterSecureStorage>(FlutterSecureStorage.new);
  sl.registerLazySingleton<AuthTokenStorage>(() => AuthTokenStorage(sl()));
  sl.registerLazySingleton<WorkspaceSelectionStorage>(
    () => WorkspaceSelectionStorage(sl()),
  );
  sl.registerLazySingleton<Dio>(() => createDio(sl()));

  // Auth
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(dio: sl(), storage: sl()),
  );
  sl.registerFactory<AuthCubit>(() => AuthCubit(sl()));

  // Profile
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl()),
  );
  sl.registerFactory<ProfileCubit>(() => ProfileCubit(sl()));

  // Projects
  sl.registerLazySingleton<ProjectRepository>(
    () => ProjectRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ProjectsCubit>(() => ProjectsCubit(sl()));

  // Workspaces
  sl.registerLazySingleton<WorkspaceRepository>(
    () => WorkspaceRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<WorkspaceCubit>(
    () => WorkspaceCubit(repository: sl(), selectionStorage: sl()),
  );
}
