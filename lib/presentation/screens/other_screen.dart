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
  String _versionFallbackText = '';
  List<ReleaseNote> _loadedReleaseNotes = [];
  bool _isInitialized = false;

  ReleaseNote? get _latestReleaseNote =>
      _loadedReleaseNotes.isEmpty ? null : _loadedReleaseNotes.first;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return;
    _isInitialized = true;
    _versionFallbackText = AppLocalizations.of(context).otherVersionFallback;
    _versionText = _versionFallbackText;
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

  String _inquiryLabel(AppLocalizations l10n, InquiryCategory category) {
    return switch (category) {
      InquiryCategory.bug => l10n.otherInquiryBug,
      InquiryCategory.request => l10n.otherInquiryRequest,
      InquiryCategory.other => l10n.otherInquiryOther,
    };
  }

  Future<void> _showReleaseHistory() async {
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
                      return _ReleaseNoteContent(note: note);
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

  Future<void> _showLatestReleaseDetails() async {
    final l10n = AppLocalizations.of(context);
    final latestNote = _latestReleaseNote;
    if (latestNote == null) return;

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
                  l10n.otherLatestUpdateDetails,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: _ReleaseNoteContent(note: latestNote),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showReleaseHistory();
                    },
                    icon: const Icon(Icons.history),
                    label: Text(l10n.otherViewAllUpdateHistory),
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
              _buildSemanticTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: l10n.otherInquiryReportBug,
                semanticLabel: l10n.otherInquiryReportBug,
                semanticHint: l10n.otherInquiryBottomSheetHint,
                onTap: () => _launchInquiry(InquiryCategory.bug),
              ),
              _buildSemanticTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: l10n.otherInquiryRequestFeature,
                semanticLabel: l10n.otherInquiryRequestFeature,
                semanticHint: l10n.otherInquiryBottomSheetHint,
                onTap: () => _launchInquiry(InquiryCategory.request),
              ),
              _buildSemanticTile(
                leading: const Icon(Icons.chat_outlined),
                title: l10n.otherInquiryElse,
                semanticLabel: l10n.otherInquiryElse,
                semanticHint: l10n.otherInquiryBottomSheetHint,
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
      'entry.1693838828':
          l10n.otherInquiryTemplate(packageInfo.version, osVersion),
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
                        Text(
                          l10n.otherPrivacySection1Title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(l10n.otherPrivacySection1Body),
                        const SizedBox(height: 12),
                        Text(
                          l10n.otherPrivacySection2Title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(l10n.otherPrivacySection2Body),
                        const SizedBox(height: 12),
                        Text(
                          l10n.otherPrivacySection3Title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(l10n.otherPrivacySection3Body),
                        const SizedBox(height: 12),
                        Text(
                          l10n.otherPrivacySection4Title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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

  Widget _buildSemanticTile({
    required Widget leading,
    required String title,
    String? subtitle,
    required String semanticLabel,
    required String semanticHint,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      hint: semanticHint,
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openSupportPage() async {
    final l10n = AppLocalizations.of(context);
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
  }

  String _latestInlineSummary(AppLocalizations l10n) {
    final latest = _latestReleaseNote;
    if (latest == null) {
      return l10n.otherNoReleaseHistory;
    }
    final firstChange = latest.changes.isEmpty ? '' : latest.changes.first;
    return l10n.otherLatestUpdateInline(
      latest.version,
      latest.date,
      firstChange,
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _SectionCard(
            title: l10n.otherSupportSectionTitle,
            subtitle: l10n.otherSupportSectionSubtitle,
            children: [
              _buildSemanticTile(
                leading: const Icon(Icons.feedback_outlined),
                title: l10n.otherInquiry,
                subtitle: l10n.otherInquirySubtitle,
                semanticLabel: l10n.otherInquirySemantic,
                semanticHint: l10n.otherInquirySemanticHint,
                trailing: FilledButton.tonalIcon(
                  onPressed: _showInquiryOptions,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l10n.otherInquiryCta),
                ),
                onTap: _showInquiryOptions,
              ),
              const Divider(height: 0),
              _buildSemanticTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: l10n.otherManual,
                subtitle: l10n.otherManualSubtitle,
                semanticLabel: l10n.otherManualSemantic,
                semanticHint: l10n.otherOpenScreenSemanticHint,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ManualScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: l10n.otherAppInfoSectionTitle,
            subtitle: l10n.otherAppInfoSectionSubtitle,
            children: [
              _buildSemanticTile(
                leading: const Icon(Icons.tag_outlined),
                title: l10n.otherVersion,
                subtitle:
                    '${l10n.otherVersionBuild(_versionText, AppConfig.buildDate)}\n${_latestInlineSummary(l10n)}',
                semanticLabel: l10n.otherVersionSemantic(_versionText),
                semanticHint: l10n.otherReleaseDetailsSemanticHint,
                onTap: _showLatestReleaseDetails,
              ),
              const Divider(height: 0),
              _buildSemanticTile(
                leading: const Icon(Icons.description_outlined),
                title: l10n.otherPrivacyPolicy,
                subtitle: l10n.otherPrivacySubtitle,
                semanticLabel: l10n.otherPrivacySemantic,
                semanticHint: l10n.otherOpenSheetSemanticHint,
                onTap: _showPrivacyPolicy,
              ),
              const Divider(height: 0),
              _buildSemanticTile(
                leading: const Icon(Icons.info_outline),
                title: l10n.otherLicenseInfo,
                subtitle: l10n.otherLicenseSubtitle,
                semanticLabel: l10n.otherLicenseSemantic,
                semanticHint: l10n.otherOpenScreenSemanticHint,
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: l10n.appTitle,
                    applicationVersion: _versionText,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: l10n.otherCommunitySectionTitle,
            subtitle: l10n.otherCommunitySectionSubtitle,
            children: [
              _buildSemanticTile(
                leading: const Icon(Icons.volunteer_activism_outlined),
                title: l10n.otherSupportTitle,
                subtitle: l10n.otherSupportSubtitle,
                semanticLabel: l10n.otherCommunitySupportSemantic,
                semanticHint: l10n.otherExternalLinkSemanticHint,
                onTap: _openSupportPage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ReleaseNoteContent extends StatelessWidget {
  const _ReleaseNoteContent({required this.note});

  final ReleaseNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'v${note.version}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              note.date,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
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
  }
}
