import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shonenx/core/models/anime/source_model.dart';
import 'package:shonenx/features/anime/view/widgets/player/bottom_controls.dart';
import 'package:shonenx/features/anime/view/widgets/player/center_controls.dart';
import 'package:shonenx/features/anime/view/widgets/player/subtitle_overlay.dart';
import 'package:shonenx/features/anime/view/widgets/player/top_controls.dart';
import 'package:shonenx/features/anime/view_model/controls_overlay_provider.dart';
import 'package:shonenx/features/anime/view_model/episode_stream_provider.dart';
import 'package:shonenx/features/anime/view_model/player_provider.dart';

class CloudstreamControls extends ConsumerWidget {
  final VoidCallback? onEpisodesPressed;

  const CloudstreamControls({
    super.key,
    this.onEpisodesPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controlsState = ref.watch(controlsOverlayProvider);
    final controlsNotifier = ref.read(controlsOverlayProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final midPoint = constraints.maxWidth / 2;
        return GestureDetector(
          onTap: controlsNotifier.showControls,
          onDoubleTapDown: (details) {
            controlsNotifier
                .handleDoubleTap(details.localPosition.dx >= midPoint);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildSkipIndicator(
                isVisible: controlsState.skipState == -1,
                isForward: false,
              ),
              _buildSkipIndicator(
                isVisible: controlsState.skipState == 1,
                isForward: true,
              ),
              AnimatedOpacity(
                opacity: controlsState.areControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: AbsorbPointer(
                  absorbing: !controlsState.areControlsVisible,
                  child: _buildControlsUI(context, ref),
                ),
              ),
              Positioned(
                bottom:
                    controlsState.areControlsVisible && !controlsState.isLocked
                        ? 150
                        : 20,
                left: 20,
                right: 20,
                child: const SubtitleOverlay(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkipIndicator({
    required bool isVisible,
    required bool isForward,
  }) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: FractionallySizedBox(
        alignment: isForward ? Alignment.centerRight : Alignment.centerLeft,
        widthFactor: 0.4,
        child: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
            colors: [Colors.black.withOpacity(isForward ? 1: 0), Colors.black.withOpacity(isForward ? 0 : 1), ],
            stops: [0, 1],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          )),
          child: Center(
            child: Icon(
              isForward
                  ? Iconsax.forward_10_seconds
                  : Iconsax.backward_10_seconds,
              size: 40,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsUI(BuildContext context, WidgetRef ref) {
    final controlsNotifier = ref.read(controlsOverlayProvider.notifier);
    final controlsState = ref.watch(controlsOverlayProvider);

    return GestureDetector(
      onTap: controlsNotifier.hideControls,
      child: Container(
        color: Colors.transparent,
        child: controlsState.isLocked
            ? _buildLockMode(context, ref)
            : _buildFullControls(context, ref),
      ),
    );
  }

  Widget _buildLockMode(BuildContext context, WidgetRef ref) {
    final controlsNotifier = ref.read(controlsOverlayProvider.notifier);
    return Center(
      child: GestureDetector(
        onTap: controlsNotifier.resetHideTimer,
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: controlsNotifier.toggleLock,
          icon: const Icon(Icons.lock_open, size: 32, color: Colors.white),
          tooltip: 'Unlock',
        ),
      ),
    );
  }

  Widget _buildFullControls(BuildContext context, WidgetRef ref) {
    final controlsState = ref.watch(controlsOverlayProvider);
    final controlsNotifier = ref.read(controlsOverlayProvider.notifier);
    final playerNotifier = ref.read(playerStateProvider.notifier);

    return Stack(
      children: [
        /// Center Controls
        Positioned.fill(
          child: Center(
            child:
                CenterControls(onInteraction: controlsNotifier.resetHideTimer),
          ),
        ),

        /// Top Controls
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: Matrix4.translationValues(
              0, controlsState.areControlsVisible ? 0 : -100, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: TopControls(
              onInteraction: controlsNotifier.resetHideTimer,
              onEpisodesPressed: onEpisodesPressed,
              onSettingsPressed: () => _showSettingsSheet(context, ref),
              onQualityPressed: () => _showQualitySheet(context, ref),
            ),
          ),
        ),

        /// Bottom Controls
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: Matrix4.translationValues(
              0, controlsState.areControlsVisible ? 0 : 150, 0),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: BottomControls(
              onInteraction: controlsNotifier.resetHideTimer,
              sliderValue: controlsState.draggedSliderValue,
              onSliderChangeStart: controlsNotifier.onSliderChangeStart,
              onForwardPressed: () => playerNotifier.forward(85),
              onSliderChanged: controlsNotifier.onSliderChanged,
              onSliderChangeEnd: controlsNotifier.onSliderChangeEnd,
              onLockPressed: controlsNotifier.toggleLock,
              onSourcePressed: () => _showSourceSheet(context, ref),
              onSubtitlePressed: () => _showSubtitleSheet(context, ref),
              onServerPressed: () => _showServerSheet(context, ref),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPlayerModalSheet(BuildContext context, WidgetRef ref,
      {required WidgetBuilder builder}) async {
    final controlsNotifier = ref.read(controlsOverlayProvider.notifier);
    controlsNotifier.cancelHideTimer();
    await showModalBottomSheet(
      context: context,
      builder: builder,
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(240),
      isScrollControlled: true,
    );
    controlsNotifier.resetHideTimer();
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) =>
      _showPlayerModalSheet(
        context,
        ref,
        builder: (context) => _SettingsSheetContent(
          onDismiss: () => Navigator.pop(context),
        ),
      );

  void _showQualitySheet(BuildContext context, WidgetRef ref) {
    final episodeData = ref.read(episodeDataProvider);
    final episodeNotifier = ref.read(episodeDataProvider.notifier);
    _showPlayerModalSheet(
      context,
      ref,
      builder: (context) => _GenericSelectionSheet<Map<String, dynamic>>(
        title: 'Quality',
        items: episodeData.qualityOptions,
        selectedIndex: episodeData.selectedQualityIdx ?? -1,
        displayBuilder: (item) => item['quality'] ?? 'Unknown',
        onItemSelected: (index) {
          episodeNotifier.changeQuality(index);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSourceSheet(BuildContext context, WidgetRef ref) {
    final episodeData = ref.read(episodeDataProvider);
    final episodeNotifier = ref.read(episodeDataProvider.notifier);
    _showPlayerModalSheet(
      context,
      ref,
      builder: (context) => _GenericSelectionSheet<Source>(
        title: 'Source',
        items: episodeData.sources,
        selectedIndex: episodeData.selectedSourceIdx ?? -1,
        displayBuilder: (item) => item.quality ?? 'Default Source',
        onItemSelected: (index) {
          episodeNotifier.changeSource(index);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showServerSheet(BuildContext context, WidgetRef ref) {
    final episodeData = ref.read(episodeDataProvider);
    final episodeNotifier = ref.read(episodeDataProvider.notifier);
    if (episodeData.selectedServer == null) return;
    _showPlayerModalSheet(
      context,
      ref,
      builder: (context) => _GenericSelectionSheet<String>(
        title: 'Server',
        items: episodeData.servers,
        selectedIndex: episodeData.servers.indexOf(episodeData.selectedServer!),
        displayBuilder: (item) => item,
        onItemSelected: (index) {
          episodeNotifier.changeServer(episodeData.servers.elementAt(index));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSubtitleSheet(BuildContext context, WidgetRef ref) {
    final episodeData = ref.read(episodeDataProvider);
    final episodeNotifier = ref.read(episodeDataProvider.notifier);
    _showPlayerModalSheet(
      context,
      ref,
      builder: (context) => _GenericSelectionSheet<Subtitle>(
        title: 'Subtitle',
        items: episodeData.subtitles,
        selectedIndex: episodeData.selectedSubtitleIdx ?? -1,
        displayBuilder: (item) => item.lang ?? 'Unknown Subtitle',
        onItemSelected: (index) {
          episodeNotifier.changeSubtitle(index);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _GenericSelectionSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final int selectedIndex;
  final String Function(T item) displayBuilder;
  final void Function(int index) onItemSelected;

  const _GenericSelectionSheet({
    required this.title,
    required this.items,
    required this.selectedIndex,
    required this.displayBuilder,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const Divider(height: 24),
            if (items.isEmpty)
              const Center(child: Text("No options available"))
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = selectedIndex == index;
                    return ListTile(
                      title: Text(displayBuilder(item)),
                      selected: isSelected,
                      trailing:
                          isSelected ? const Icon(Iconsax.tick_circle) : null,
                      onTap: () => onItemSelected(index),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheetContent extends ConsumerWidget {
  final VoidCallback onDismiss;
  const _SettingsSheetContent({required this.onDismiss});

  void _showDialog(BuildContext context,
      {required Widget Function(BuildContext) builder}) {
    showDialog(context: context, builder: builder).then((_) {
      if (!context.mounted) return;
      if (Navigator.of(context).canPop()) onDismiss();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Settings", style: Theme.of(context).textTheme.headlineSmall),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Iconsax.speedometer),
              title: const Text("Playback Speed"),
              trailing: Text(
                  "${ref.watch(playerStateProvider.select((p) => p.playbackSpeed))}x"),
              onTap: () =>
                  _showDialog(context, builder: (ctx) => _SpeedDialog()),
            ),
            ListTile(
              leading: const Icon(Iconsax.crop),
              title: const Text("Video Fit"),
              trailing: Text(_fitModeToString(
                  ref.watch(playerStateProvider.select((p) => p.fit)))),
              onTap: () => _showDialog(context, builder: (ctx) => _FitDialog()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SpeedDialog> createState() => _SpeedDialogState();
}

class _SpeedDialogState extends ConsumerState<_SpeedDialog> {
  late double _selectedSpeed;

  @override
  void initState() {
    super.initState();
    _selectedSpeed = ref.read(playerStateProvider).playbackSpeed;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Playback Speed"),
      content: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: [0.5, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]
            .map((speed) => ChoiceChip(
                  label: Text("${speed}x"),
                  selected: _selectedSpeed == speed,
                  onSelected: (isSelected) {
                    if (isSelected) setState(() => _selectedSpeed = speed);
                  },
                ))
            .toList(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        TextButton(
          onPressed: () {
            ref.read(playerStateProvider.notifier).setSpeed(_selectedSpeed);
            Navigator.pop(context);
          },
          child: const Text("OK"),
        ),
      ],
    );
  }
}

class _FitDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FitDialog> createState() => _FitDialogState();
}

class _FitDialogState extends ConsumerState<_FitDialog> {
  late BoxFit _selectedFit;
  static const fitModes = [BoxFit.contain, BoxFit.cover, BoxFit.fill];

  @override
  void initState() {
    super.initState();
    _selectedFit = ref.read(playerStateProvider).fit;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Video Fit"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: fitModes
            .map((fit) => RadioListTile<BoxFit>(
                  title: Text(_fitModeToString(fit)),
                  value: fit,
                  groupValue: _selectedFit,
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedFit = value);
                  },
                ))
            .toList(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        TextButton(
          onPressed: () {
            ref.read(playerStateProvider.notifier).setFit(_selectedFit);
            Navigator.pop(context);
          },
          child: const Text("OK"),
        ),
      ],
    );
  }
}

String _fitModeToString(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'Contain';
    case BoxFit.cover:
      return 'Cover';
    case BoxFit.fill:
      return 'Fill';
    default:
      return 'Fit';
  }
}
