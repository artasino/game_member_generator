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
import '../../l10n/app_localizations.dart';
import 'manual_screen.dart';

enum InquiryCategory { bug, request, other }

class OtherScreen extends StatefulWidget {
  const OtherScreen({super.key});

  @override
  State<OtherScreen> createState() => _OtherScreenState();
}

class _OtherScreenState extends State<OtherScreen> {
  String _versionText = '';
  List<ReleaseNote> _loadedReleaseNotes = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (mounted) {
      _versionText = AppLocalizations.of(context).otherVersionFallback;
    }
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
      return AppLocalizations.of(context).otherVersionFallback;
    }
    return 'v${_loadedReleaseNotes.first.version}';
  }

  String _inquiryLabel(AppLocalizations l10n, InquiryCategory category) {
    return switch (category) {
      InquiryCategory.bug => l10n.otherInquiryBug,
      InquiryCategory.request => l10n.otherInquiryRequest,
      InquiryCategory.other => l10n.otherInquiryOther,
    };
  }

  Future<void> _showReleaseNotes() async {
    final l10n = AppLocalizations.of(context);
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
                  l10n.otherUpdateHistory,
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
    final l10n = AppLocalizations.of(context);
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
                  l10n.otherInquiryTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(l10n.otherInquiryReportBug),
                onTap: () => _launchInquiry(InquiryCategory.bug),
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(l10n.otherInquiryRequestFeature),
                onTap: () => _launchInquiry(InquiryCategory.request),
              ),
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: Text(l10n.otherInquiryElse),
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

    final l10n = AppLocalizations.of(context);
    final packageInfo = await PackageInfo.fromPlatform();
    String osVersion = l10n.otherUnknown;
    if (kIsWeb) {
      osVersion = l10n.otherWeb;
    } else if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      osVersion = l10n.otherAndroid(androidInfo.version.release);
    } else if (Platform.isIOS) {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      osVersion = l10n.otherIos(iosInfo.systemVersion);
    }

    const String formBaseUrl =
        'https://docs.google.com/forms/d/e/1FAIpQLScSUXfMzuuritwD9rcNPlak6ELnwiVTFPnn2RaRBkNzkP02vQ/viewform';

    final Uri url = Uri.parse(formBaseUrl).replace(queryParameters: {
      'usp': 'pp_url',
      'entry.371796673': _inquiryLabel(l10n, category),
      'entry.1693838828': l10n.otherInquiryTemplate(packageInfo.version, osVersion),
    });

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.otherOpenFormFailed)),
        );
      }
    }
  }

  Future<void> _showPrivacyPolicy() async {
    final l10n = AppLocalizations.of(context);
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
                  l10n.otherPrivacyPolicy,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.otherPrivacySection1Title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(l10n.otherPrivacySection1Body),
                        const SizedBox(height: 12),
                        Text(l10n.otherPrivacySection2Title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(l10n.otherPrivacySection2Body),
                        const SizedBox(height: 12),
                        Text(l10n.otherPrivacySection3Title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(l10n.otherPrivacySection3Body),
                        const SizedBox(height: 12),
                        Text(l10n.otherPrivacySection4Title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(l10n.otherPrivacySection4Body),
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.otherScreenTitle),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l10n.otherManual),
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
            title: Text(l10n.otherInquiry),
            subtitle: Text(l10n.otherInquirySubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showInquiryOptions,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.tag_outlined),
            title: Text(l10n.otherVersion),
            subtitle: Text(l10n.otherVersionBuild(_versionText, AppConfig.buildDate)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showReleaseNotes,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.otherPrivacyPolicy),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showPrivacyPolicy,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.otherLicenseInfo),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: _versionText,
              );
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: Text(l10n.otherSupportTitle),
            subtitle: Text(l10n.otherSupportSubtitle),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.otherMoveToExternal),
                  content: Text(l10n.otherMoveToExternalDescription),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.commonCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(l10n.otherMove),
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
