import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shonenx/core/anilist/services/anilist_service.dart';
import 'package:shonenx/core/models/anilist/fuzzy_date.dart';
import 'package:shonenx/core/models/anilist/media.dart';
import 'package:shonenx/core/services/auth_provider_enum.dart';
import 'package:shonenx/core/utils/app_logger.dart';
import 'package:shonenx/features/auth/view_model/auth_notifier.dart';
import 'package:shonenx/features/watchlist/view_model/watchlist_notifier.dart';
import 'package:collection/collection.dart';
import 'package:shonenx/shared/providers/anime_repo_provider.dart';

/// Bottom sheet for editing anime list entry
class EditListBottomSheet extends ConsumerStatefulWidget {
  final Media anime;

  const EditListBottomSheet({
    super.key,
    required this.anime,
  });

  @override
  ConsumerState<EditListBottomSheet> createState() =>
      _EditListBottomSheetState();
}

class _EditListBottomSheetState extends ConsumerState<EditListBottomSheet> {
  static const List<String> _statusOptions = [
    'CURRENT',
    'PLANNING',
    'COMPLETED',
    'REPEATING',
    'PAUSED',
    'DROPPED'
  ];

  late String _selectedStatus;
  late TextEditingController _progressController;
  late TextEditingController _scoreController;
  late TextEditingController _repeatsController;
  late TextEditingController _notesController;
  DateTime? _startDate;
  DateTime? _completedDate;
  late bool _isPrivate;
  bool _isSaving = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _selectedStatus = 'PLANNING';
    _progressController = TextEditingController(text: '0');
    _scoreController = TextEditingController(text: '0');
    _repeatsController = TextEditingController(text: '0');
    _notesController = TextEditingController();
    _isPrivate = false;
    _loadEntry(ref);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _scoreController.dispose();
    _repeatsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry(WidgetRef ref) async {
    if (_isFetching || !mounted) return;

    setState(() => _isFetching = true);

    final auth = ref.read(authProvider);
    if (auth.authPlatform == null) {
      _showSnackBar('Login Required', 'Sar plz login!', ContentType.failure);
      setState(() => _isFetching = false);
      return;
    }

    final watchlist = ref.read(watchlistProvider);
    final watchlistNotifier = ref.read(watchlistProvider.notifier);
    final animeRepo = ref.read(animeRepositoryProvider);

    try {
      if (auth.authPlatform == AuthPlatform.anilist) {
        var entry = watchlist.lists.values
            .expand((e) => e)
            .firstWhereOrNull((m) => m.id == widget.anime.id);

        entry ??= await animeRepo.getAnimeEntry(widget.anime.id!);
        if (entry != null) {
          watchlistNotifier.addEntry(entry);
          setState(() {
            _selectedStatus = entry?.status ?? _selectedStatus;
            _progressController.text =
                entry?.progress.toString() ?? _progressController.text;
            _scoreController.text =
                entry?.score.toString() ?? _scoreController.text;
            _repeatsController.text =
                entry?.repeat.toString() ?? _repeatsController.text;
            _notesController.text = entry?.notes ?? _notesController.text;
            _startDate = entry?.startedAt?.toDateTime;
            _completedDate = entry?.completedAt?.toDateTime;
            _isPrivate = entry?.isPrivate ?? _isPrivate;
          });
        }
      } else {
        _showSnackBar(
          'Info',
          'MAL support not implemented yet.',
          ContentType.warning,
        );
      }
    } catch (e, st) {
      debugPrint('Error loading entry: $e\n$st');
      _showSnackBar('Error', 'Failed to load entry', ContentType.failure);
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _saveChanges(WidgetRef ref) async {
    final auth = ref.read(authProvider);
    if (auth.authPlatform == null) {
      _showSnackBar('Login Required', 'Sar plz login!', ContentType.failure);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final score = double.tryParse(_scoreController.text) ?? 0.0;
      final progress = int.tryParse(_progressController.text) ?? 0;
      final repeats = int.tryParse(_repeatsController.text) ?? 0;

      switch (auth.authPlatform!) {
        case AuthPlatform.anilist:
          await ref.read(anilistServiceProvider).updateUserAnimeList(
                mediaId: widget.anime.id!,
                status: _selectedStatus,
                score: score,
                private: _isPrivate,
                startedAt: FuzzyDateInput(
                  year: _startDate?.year,
                  month: _startDate?.month,
                  day: _startDate?.day,
                ),
                completedAt: FuzzyDateInput(
                  year: _completedDate?.year,
                  month: _completedDate?.month,
                  day: _completedDate?.day,
                ),
                repeat: repeats,
                notes: _notesController.text,
                progress: progress,
              );
          _showSnackBar(
            'Success',
            'Animelist updated successfully',
            ContentType.success,
          );
          break;

        case AuthPlatform.mal:
          _showSnackBar(
            'Info',
            'MAL support not implemented yet.',
            ContentType.warning,
          );
          break;
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, st) {
      AppLogger.e('Error while saving anime list: $e\n$st');
      _showSnackBar(
        'Error',
        'Failed to update anime list. Please try again.',
        ContentType.failure,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String title, String message, ContentType type) {
    if (!mounted) return;
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: title,
        message: message,
        contentType: type,
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  Future<void> _pickDate(bool isStartDate) async {
    final initialDate =
        (isStartDate ? _startDate : _completedDate) ?? DateTime.now();
    final firstDate =
        isStartDate ? DateTime(1980) : (_startDate ?? DateTime(1980));

    final newDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now(),
    );

    if (newDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = newDate;
          if (_completedDate != null && _completedDate!.isBefore(_startDate!)) {
            _completedDate = null;
          }
        } else {
          _completedDate = newDate;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalEpisodes = widget.anime.episodes;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Edit Entry',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                if (_isFetching) const CircularProgressIndicator()
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildStatusDropdown()),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField('Score', _scoreController,
                        suffixText: '/ 10')),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Progress', _progressController,
                suffixText: totalEpisodes != null ? '/ $totalEpisodes' : 'eps',
                suffixIcon: IconButton(
                  icon: const Icon(Iconsax.add_circle),
                  onPressed: () {
                    int current = int.tryParse(_progressController.text) ?? 0;
                    if (totalEpisodes == null || current < totalEpisodes) {
                      _progressController.text = '${current + 1}';
                    }
                  },
                )),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildDateField(
                        'Started At', _startDate, () => _pickDate(true))),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildDateField('Completed At', _completedDate,
                        () => _pickDate(false))),
              ],
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Additional Options'),
              shape: const Border(),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [
                _buildTextField('Total Repeats', _repeatsController),
                const SizedBox(height: 16),
                _buildTextField('Notes', _notesController, maxLines: 3),
                SwitchListTile(
                  title: const Text('Private'),
                  value: _isPrivate,
                  onChanged: (val) => setState(() => _isPrivate = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : () => _saveChanges(ref),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Iconsax.save_2),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedStatus,
      onChanged: (value) {
        if (value != null) setState(() => _selectedStatus = value);
      },
      items: _statusOptions
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item
                    .toLowerCase()
                    .replaceFirst(item[0].toLowerCase(), item[0])),
              ))
          .toList(),
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {String? suffixText = '', int? maxLines = 1, Widget? suffixIcon}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType:
          maxLines == 1 ? TextInputType.number : TextInputType.multiline,
      inputFormatters:
          maxLines == 1 ? [FilteringTextInputFormatter.digitsOnly] : [],
      decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
          suffixText: suffixText,
          suffixIcon: suffixIcon),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    final formattedDate =
        date != null ? DateFormat.yMMMd().format(date) : 'Select Date';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(formattedDate),
      ),
    );
  }
}
