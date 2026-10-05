import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nart_chat/controllers/chat_controller.dart';
import 'package:nart_chat/controllers/settings_controller.dart';
import 'package:nart_chat/utils/app_theme.dart';
import 'package:nart_chat/views/chat_view.dart';
import 'package:nart_chat/views/widgets/glass.dart';
import 'package:nart_chat/views/widgets/session_drawer.dart';

/// Çekmece, model seçici ve aktif sohbet.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(chatControllerProvider.select((state) => state.notice), (
      previous,
      next,
    ) {
      if (next == null || next == previous) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next)));
      ref.read(chatControllerProvider.notifier).clearNotice();
    });

    final chat = ref.watch(chatControllerProvider);
    final canExport = (chat.activeSession?.messages.isNotEmpty ?? false);

    return Scaffold(
      drawer: const SessionDrawer(),
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 4,
        leading: Builder(
          builder: (context) {
            return IconButton(
              tooltip: 'Menü',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            );
          },
        ),
        title: const Text(
          'NART Chatbot',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: AppColors.muted,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: const SizedBox.expand(),
          ),
        ),
        actions: [
          const _ProfileSwitcher(),
          IconButton(
            tooltip: 'Dışa Aktar',
            onPressed: canExport
                ? () => ref.read(chatControllerProvider.notifier).exportActive()
                : null,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Yeni sohbet',
            onPressed: () =>
                ref.read(chatControllerProvider.notifier).startNewChat(),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: const SafeArea(child: ChatView()),
    );
  }
}

class _ProfileSwitcher extends ConsumerWidget {
  const _ProfileSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final session = ref.watch(
      chatControllerProvider.select((state) => state.activeSession),
    );
    final profile = settings.profileById(session?.profileId) ?? settings.active;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: InkWell(
        onTap: () => _openProfiles(context, ref),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// Kayıtlı profilleri buzlu cam listesinde açar.
  Future<void> _openProfiles(BuildContext context, WidgetRef ref) {
    return showGlassSheet<void>(
      context: context,
      builder: (sheetContext) {
        final settings = ref.read(settingsControllerProvider);
        final session = ref.read(chatControllerProvider).activeSession;
        final selected = session?.profileId ?? settings.activeProfileId;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Model',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final profile in settings.profiles)
                ListTile(
                  title: Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    profile.modelName.isEmpty
                        ? profile.endpoint
                        : profile.modelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: profile.id == selected
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref
                        .read(chatControllerProvider.notifier)
                        .selectProfile(profile.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
