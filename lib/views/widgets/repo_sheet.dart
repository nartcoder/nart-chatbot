import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nart_chat/controllers/chat_controller.dart';
import 'package:nart_chat/controllers/settings_controller.dart';
import 'package:nart_chat/models/cursor_profile.dart';
import 'package:nart_chat/services/api_exception.dart';
import 'package:nart_chat/utils/app_theme.dart';
import 'package:nart_chat/utils/endpoint.dart';
import 'package:nart_chat/utils/providers.dart';
import 'package:nart_chat/views/widgets/glass.dart';

/// Depo adresi yapıştırmak ve kayıtlı repoları seçmek için alttan sayfa açar.
Future<void> showRepoSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (sheetContext) => const RepoSheet(),
  );
}

/// Kayıtlı GitHub ve GitLab adresleri ile yeni bir bağlantı alanı.
class RepoSheet extends ConsumerStatefulWidget {
  const RepoSheet({super.key});

  @override
  ConsumerState<RepoSheet> createState() => _RepoSheetState();
}

class _RepoSheetState extends ConsumerState<RepoSheet> {
  final TextEditingController _url = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// Yazılan adresi listeye ekler ve bu sohbete bağlar.
  Future<void> _saveTyped() async {
    final value = _url.text.trim();
    if (!isHttpUrl(value)) {
      setState(() => _error = 'Geçerli bir http veya https repo adresi yaz.');
      return;
    }
    setState(() => _error = null);
    await ref.read(settingsControllerProvider.notifier).addRepo(value);
    await ref.read(chatControllerProvider.notifier).setRepoUrl(value);
    _url.clear();
  }

  /// Cursor hesabındaki GitHub depolarını çeker.
  Future<void> _loadGithub() async {
    final settings = ref.read(settingsControllerProvider);
    final chat = ref.read(chatControllerProvider);
    final profile =
        settings.profileById(chat.activeSession?.profileId) ?? settings.active;
    if (!isCursorProfile(profile)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final urls = await ref
          .read(cursorAgentServiceProvider)
          .listRepositories(profile: profile);
      for (final url in urls) {
        await ref.read(settingsControllerProvider.notifier).addRepo(url);
      }
      if (mounted && urls.isEmpty) {
        setState(() => _error = 'Bağlı GitHub deposu bulunamadı.');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Depolar alınamadı. Yeniden dene.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final selected = ref.watch(
      chatControllerProvider.select((state) => state.selectedRepoUrl),
    );
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Depo',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'İlk mesajda seçili repo ajana bağlanır. GitHub veya GitLab adresi yapıştır.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveTyped(),
              decoration: const InputDecoration(
                hintText: 'https://github.com/org/repo',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _saveTyped,
                    child: const Text('Kaydet ve seç'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'GitHub repolarını getir',
                  onPressed: _loading ? null : _loadGithub,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, height: 1.3),
              ),
            ],
            if (settings.savedRepos.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final url in settings.savedRepos)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: Icon(
                          url == selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: AppColors.accent,
                        ),
                        trailing: IconButton(
                          tooltip: 'Kaldır',
                          onPressed: () async {
                            await ref
                                .read(settingsControllerProvider.notifier)
                                .removeRepo(url);
                            if (selected == url) {
                              await ref
                                  .read(chatControllerProvider.notifier)
                                  .setRepoUrl(null);
                            }
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                        onTap: () async {
                          await ref
                              .read(chatControllerProvider.notifier)
                              .setRepoUrl(url);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
