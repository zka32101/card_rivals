import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/daily_emotion_card.dart';
import '../providers/daily_emotion_provider.dart';
import '../l10n/app_localizations.dart';

class DailyEmotionScreen extends ConsumerStatefulWidget {
  const DailyEmotionScreen({super.key});

  @override
  ConsumerState<DailyEmotionScreen> createState() => _DailyEmotionScreenState();
}

class _DailyEmotionScreenState extends ConsumerState<DailyEmotionScreen> {
  EmotionType? selectedEmotion;
  final messageController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _submitEmotion() async {
    final t = AppLocalizations.of(context)!;
    if (selectedEmotion == null || messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.dailyEmotion_selectFeelingAndMessage)),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await ref.read(
        createDailyEmotionProvider((selectedEmotion!, messageController.text.trim())).future,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.dailyEmotion_cardCreatedSuccess)),
        );
        messageController.clear();
        setState(() => selectedEmotion = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.dailyEmotion_errorWithMessage('$e'))),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final todayEmotion = ref.watch(todayEmotionCardProvider);
    final stats = ref.watch(emotionStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.dailyEmotion_title),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: todayEmotion.when(
          data: (emotion) {
            if (emotion != null) {
              return _buildCompletedView(emotion, stats);
            }
            return _buildInputView(stats);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(t.dailyEmotion_errorWithMessage('$error')),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedView(DailyEmotionCard emotion, AsyncValue<EmotionStats> statsAsync) {
    final t = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getEmotionColor(emotion.emotion).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getEmotionColor(emotion.emotion)),
            ),
            child: Column(
              children: [
                Text(
                  emotion.emotionEmoji,
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 12),
                Text(
                  t.dailyEmotion_todaysFeeling(switch (emotion.emotion) {
                    EmotionType.joy => t.dailyEmotion_joyShort,
                    EmotionType.anger => t.dailyEmotion_angerShort,
                    EmotionType.sadness => t.dailyEmotion_sadnessShort,
                  }),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  emotion.userMessage,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          statsAsync.when(
            data: (stats) => _buildStatsWidget(stats),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              messageController.clear();
              setState(() => selectedEmotion = null);
              ref.invalidate(todayEmotionCardProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
            ),
            child: Text(t.dailyEmotion_viewAnotherCard),
          ),
        ],
      ),
    );
  }

  Widget _buildInputView(AsyncValue<EmotionStats> statsAsync) {
    final t = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statsAsync.when(
            data: (stats) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(t.dailyEmotion_streakDays(stats.currentStreak), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          Text(
            t.dailyEmotion_howAreYouFeeling,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEmotionButton(EmotionType.joy, '😊', t.dailyEmotion_joyShort),
              _buildEmotionButton(EmotionType.anger, '😠', t.dailyEmotion_angerShort),
              _buildEmotionButton(EmotionType.sadness, '😢', t.dailyEmotion_sadnessShort),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            t.dailyEmotion_memoLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: messageController,
            maxLength: 50,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: t.dailyEmotion_memoHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : _submitEmotion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.dailyEmotion_createCardButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionButton(EmotionType emotion, String emoji, String label) {
    final isSelected = selectedEmotion == emotion;
    return GestureDetector(
      onTap: () => setState(() => selectedEmotion = emotion),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _getEmotionColor(emotion).withValues(alpha: 0.2) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? _getEmotionColor(emotion) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsWidget(EmotionStats stats) {
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.dailyEmotion_monthlyMoodTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildStatRow('😊 ${t.dailyEmotion_joyShort}', EmotionType.joy, stats.joyDays, stats.joyPercent),
          _buildStatRow('😠 ${t.dailyEmotion_angerShort}', EmotionType.anger, stats.angerDays, stats.angerPercent),
          _buildStatRow('😢 ${t.dailyEmotion_sadnessShort}', EmotionType.sadness, stats.sadnessDays, stats.sadnessPercent),
          const SizedBox(height: 12),
          Text(
            t.dailyEmotion_totalDays(stats.totalDays),
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, EmotionType emotion, int count, double percent) {
    final t = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              widthFactor: percent / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: _getEmotionColor(emotion),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        Text(t.dailyEmotion_statDaysPercent(count, percent.toStringAsFixed(0))),
      ],
    );
  }

  Color _getEmotionColor(EmotionType emotion) {
    return switch (emotion) {
      EmotionType.joy => const Color(0xFFFFD700),
      EmotionType.anger => const Color(0xFFE74C3C),
      EmotionType.sadness => const Color(0xFF3498DB),
    };
  }
}
