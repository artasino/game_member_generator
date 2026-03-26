import 'package:game_member_generator/infrastructure/persistence/app_repositories.dart';
import 'package:game_member_generator/infrastructure/persistence/repository_provider_stub.dart'
    if (dart.library.io) 'package:game_member_generator/infrastructure/persistence/repository_provider_io.dart'
    if (dart.library.html) 'package:game_member_generator/infrastructure/persistence/repository_provider_web.dart'
    as provider;

Future<AppRepositories> createRepositories() => provider.createRepositories();
