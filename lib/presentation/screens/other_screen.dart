import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../domain/entities/release_note.dart';
import 'manual_screen.dart';

enum InquiryCategory {
  bug('不具合'),
  request('機能改善要望'),
  other('その他');

  final String label;

  const InquiryCategory(this.label);
}

class OtherScreen extends StatefulWidget {
  const OtherScreen({super.key});

  @override
  State<OtherScreen> createState() => _OtherScreenState();
}

class _OtherScreenState extends State<OtherScreen> {
  static const String _versionFallbackText = '取得できませんでした';

  String _versionText = _versionFallbackText;
  List<ReleaseNote> _loadedReleaseNotes = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadVersion(),
      _loadNotes(),
    ]);
  }

  Future<void> _loadNotes() async {
    try {
      final String response =
          await rootBundle.loadString('assets/changelog.json');
      final List<dynamic> data = json.decode(response);
      final notes = data
          .map((json) => ReleaseNote.fromJson(json as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _loadedReleaseNotes = notes;
      });
    } catch (e) {
      debugPrint('Failed to load changelog: $e');
    }
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final normalizedVersion = packageInfo.version.trim();
      final normalizedBuild = packageInfo.buildNumber.trim();
      final hasVersion =
          normalizedVersion.isNotEmpty && normalizedVersion != '0.0.0';

      if (!mounted) return;
      setState(() {
        if (hasVersion) {
          _versionText = normalizedBuild.isEmpty
              ? 'v$normalizedVersion'
              : 'v$normalizedVersion+$normalizedBuild';
          return;
        }
        _versionText = _latestReleaseVersionText;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _versionText = _latestReleaseVersionText;
      });
    }
  }

  String get _latestReleaseVersionText {
    if (_loadedReleaseNotes.isEmpty) {
      return _versionFallbackText;
    }
    return 'v${_loadedReleaseNotes.first.version}';
  }

  Future<void> _showReleaseNotes() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'アップデート履歴',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _loadedReleaseNotes.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final note = _loadedReleaseNotes[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'v${note.version}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                note.date,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...note.changes.map(
                            (change) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $change'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInquiryOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'ご意見・お問い合わせ',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('不具合を報告する'),
                onTap: () => _launchInquiry(InquiryCategory.bug),
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('機能改善を要望する'),
                onTap: () => _launchInquiry(InquiryCategory.request),
              ),
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('その他のお問い合わせ'),
                onTap: () => _launchInquiry(InquiryCategory.other),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchInquiry(InquiryCategory category) async {
    Navigator.pop(context);

    final packageInfo = await PackageInfo.fromPlatform();
    String osVersion = 'Unknown';
    if (kIsWeb) {
      osVersion = 'Web';
    } else if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      osVersion = 'Android ${androidInfo.version.release}';
    } else if (Platform.isIOS) {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      osVersion = 'iOS ${iosInfo.systemVersion}';
    }

    // Google Form の URL
    const String formBaseUrl =
        'https://docs.google.com/forms/d/e/1FAIpQLScSUXfMzuuritwD9rcNPlak6ELnwiVTFPnn2RaRBkNzkP02vQ/viewform';

    final Uri url = Uri.parse(formBaseUrl).replace(queryParameters: {
      'usp': 'pp_url',
      'entry.371796673': category.label, // カテゴリ
      'entry.1693838828':
          '【環境情報】\nApp: v${packageInfo.version}\nOS: $osVersion\n\n【お問い合わせ内容】\n', // 内容（自動挿入）
    });

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フォームを開けませんでした')),
        );
      }
    }
  }

  Future<void> _showPrivacyPolicy() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'プライバシーポリシー',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('1. 情報の収集',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            '本アプリでは、お問い合わせ時にメールアドレス、端末情報（OSバージョン、機種名）、およびお問い合わせ内容を収集します。'),
                        SizedBox(height: 12),
                        Text('2. 利用目的',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('収集した情報は、不具合の調査、機能改善の検討、およびお問い合わせへの回答のみに利用します。'),
                        SizedBox(height: 12),
                        Text('3. 第三者提供',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('法令に基づく場合を除き、取得した個人情報を第三者に提供することはありません。'),
                        SizedBox(height: 12),
                        Text('4. データの管理',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('収集したデータは、Google Cloud Firestore にて適切に管理・保存されます。'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('その他'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('マニュアル'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ManualScreen(),
                ),
              );
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('ご意見・お問い合わせ'),
            subtitle: const Text('不具合の報告や機能改善の要望はこちら'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showInquiryOptions,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.tag_outlined),
            title: const Text('バージョン'),
            subtitle: Text('$_versionText (Build: ${AppConfig.buildDate})'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showReleaseNotes,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showPrivacyPolicy,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('ライセンス情報'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Game Member Generator',
                applicationVersion: _versionText,
              );
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: const Text('🏸 応援する'),
            subtitle: const Text('開発者が無償で作成しています。\n練習のお供に役立ったら、ぜひ応援をお願いします！'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('外部サイトへ移動'),
                  content: const Text('応援ページ（外部サイト）へ移動します。よろしいですか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('移動する'),
                    ),
                  ],
                ),
              );

              if (ok == true) {
                final url = Uri.parse('https://ofuse.me/37202113/letter');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
