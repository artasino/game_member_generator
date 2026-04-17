import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/release_note.dart';
import '../../domain/repository/inquiry_repository.dart';
import 'manual_screen.dart';

class OtherScreen extends StatefulWidget {
  final InquiryRepository inquiryRepository;

  const OtherScreen({super.key, required this.inquiryRepository});

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

  Future<void> _showInquiryForm() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    InquiryCategory selectedCategory = InquiryCategory.bug;
    bool isSending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ご意見・お問い合わせ',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<InquiryCategory>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'カテゴリ',
                            border: OutlineInputBorder(),
                          ),
                          items: InquiryCategory.values.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category.label),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => selectedCategory = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'メールアドレス',
                            hintText: '返信が必要な場合は入力してください',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: messageController,
                          decoration: const InputDecoration(
                            labelText: '内容',
                            hintText: '不具合の詳細や改善の要望をご記入ください',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 5,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '内容を入力してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isSending
                              ? null
                              : () async {
                                  if (formKey.currentState?.validate() ??
                                      false) {
                                    setModalState(() => isSending = true);
                                    try {
                                      final packageInfo =
                                          await PackageInfo.fromPlatform();
                                      String osVersion = 'Unknown';
                                      if (kIsWeb) {
                                        osVersion = 'Web';
                                      } else if (Platform.isAndroid) {
                                        final androidInfo =
                                            await DeviceInfoPlugin()
                                                .androidInfo;
                                        osVersion =
                                            'Android ${androidInfo.version.release}';
                                      } else if (Platform.isIOS) {
                                        final iosInfo =
                                            await DeviceInfoPlugin().iosInfo;
                                        osVersion =
                                            'iOS ${iosInfo.systemVersion}';
                                      }

                                      final inquiry = Inquiry(
                                        email: emailController.text,
                                        category: selectedCategory,
                                        message: messageController.text,
                                        osVersion: osVersion,
                                        appVersion: packageInfo.version,
                                      );

                                      await widget.inquiryRepository
                                          .sendInquiry(inquiry);

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('送信しました。ありがとうございます！')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('送信に失敗しました: $e')),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setModalState(() => isSending = false);
                                      }
                                    }
                                  }
                                },
                          child: isSending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('送信する'),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
            onTap: _showInquiryForm,
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
