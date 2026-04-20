import 'package:flutter/material.dart';
import 'package:game_member_generator/config/app_config.dart';
import 'package:game_member_generator/infrastructure/persistence/app_repositories.dart';
import 'infrastructure/persistence/repository_provider.dart';
import 'presentation/di/app_scope.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 設定ファイルの読み込み
  await AppConfig.load();

  // プラットフォームごとの永続化リポジトリを準備
  final repositories = await createRepositories();

  runApp(MyApp(
    repositories: repositories,
  ));
}

class MyApp extends StatelessWidget {
  final AppRepositories repositories;

  const MyApp({
    super.key,
    required this.repositories,
  });

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repositories: repositories,
      child: MaterialApp(
        title: 'Game Member Generator',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(context),
        home: const MainNavigationScreen(),
      ),
    );
  }
}
