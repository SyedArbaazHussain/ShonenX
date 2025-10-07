import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shonenx/features/anime/view_model/player_provider.dart';

@immutable
class ControlsOverlayState {
  final bool areControlsVisible;
  final bool isLocked;
  final int skipState; // 0 = none, -1 = backward, 1 = forward
  final double? draggedSliderValue;

  const ControlsOverlayState({
    this.areControlsVisible = true,
    this.isLocked = false,
    this.skipState = 0,
    this.draggedSliderValue,
  });

  ControlsOverlayState copyWith({
    bool? areControlsVisible,
    bool? isLocked,
    int? skipState,
    ValueGetter<double?>? draggedSliderValue,
  }) {
    return ControlsOverlayState(
      areControlsVisible: areControlsVisible ?? this.areControlsVisible,
      isLocked: isLocked ?? this.isLocked,
      skipState: skipState ?? this.skipState,
      draggedSliderValue: draggedSliderValue != null
          ? draggedSliderValue()
          : this.draggedSliderValue,
    );
  }
}

class ControlsOverlayNotifier extends StateNotifier<ControlsOverlayState> {
  ControlsOverlayNotifier(this.ref) : super(const ControlsOverlayState()) {
    resetHideTimer();
  }

  final Ref ref;
  Timer? _hideControlsTimer;
  Timer? _hideSkipIndicatorTimer;

  void showControls() {
    if (state.isLocked) return;
    if (!state.areControlsVisible) {
      state = state.copyWith(areControlsVisible: true);
    }
    resetHideTimer();
  }

  void hideControls() {
    if (state.areControlsVisible) {
      state = state.copyWith(areControlsVisible: false);
    }
    _hideControlsTimer?.cancel();
  }

  void cancelHideTimer() {
    _hideControlsTimer?.cancel();
  }

  void resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (state.isLocked || !state.areControlsVisible) return;
    _hideControlsTimer = Timer(const Duration(seconds: 5), hideControls);
  }

  void toggleLock() {
    state = state.copyWith(isLocked: !state.isLocked, areControlsVisible: true);
    resetHideTimer();
  }

  void handleDoubleTap(bool isForward) {
    if (state.isLocked) return;

    final playerNotifier = ref.read(playerStateProvider.notifier);
    final currentPosition = ref.read(playerStateProvider).position;

    _hideSkipIndicatorTimer?.cancel();

    if (isForward) {
      playerNotifier.seek(currentPosition + const Duration(seconds: 10));
      state = state.copyWith(skipState: 1);
    } else {
      playerNotifier.seek(currentPosition - const Duration(seconds: 10));
      state = state.copyWith(skipState: -1);
    }

    _hideSkipIndicatorTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        state = state.copyWith(skipState: 0);
      }
    });
  }

  void onSliderChangeStart(double value) {
    cancelHideTimer();
    state = state.copyWith(draggedSliderValue: () => value);
  }

  void onSliderChanged(double value) {
    state = state.copyWith(draggedSliderValue: () => value);
  }

  void onSliderChangeEnd(double value) {
    ref
        .read(playerStateProvider.notifier)
        .seek(Duration(milliseconds: value.round()));
    state = state.copyWith(draggedSliderValue: () => null);
    resetHideTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _hideSkipIndicatorTimer?.cancel();
    super.dispose();
  }
}

final controlsOverlayProvider =
    StateNotifierProvider.autoDispose<ControlsOverlayNotifier, ControlsOverlayState>(
        (ref) => ControlsOverlayNotifier(ref));