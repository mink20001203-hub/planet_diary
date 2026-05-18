import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/achievement_provider.dart';

class AchievementBadgeStrip extends StatelessWidget {
  const AchievementBadgeStrip({
    super.key,
    required this.achievements,
    this.compact = false,
  });

  final List<Achievement> achievements;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((item) => item.unlocked).length;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1420),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ACHIEVEMENTS',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    color: const Color(0xFFFFD246).withOpacity(0.7),
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$unlocked / ${achievements.length}',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: achievements.map((achievement) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _AchievementBadge(
                    achievement: achievement,
                    compact: compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({
    required this.achievement,
    required this.compact,
  });

  final Achievement achievement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final accent = unlocked ? const Color(0xFFFFD246) : Colors.white;

    return Container(
      width: compact ? 126 : 144,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked
            ? const Color(0xFFFFD246).withOpacity(0.1)
            : Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? const Color(0xFFFFD246).withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                achievement.icon,
                style: TextStyle(
                  fontSize: compact ? 18 : 20,
                  color: unlocked ? null : Colors.white30,
                ),
              ),
              const Spacer(),
              Icon(
                unlocked ? Icons.lock_open : Icons.lock_outline,
                size: 14,
                color: accent.withOpacity(unlocked ? 0.8 : 0.25),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              color: Colors.white.withOpacity(unlocked ? 0.9 : 0.42),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansKr(
              fontSize: 10,
              height: 1.35,
              color: Colors.white.withOpacity(unlocked ? 0.55 : 0.28),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: achievement.progress,
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(
                accent.withOpacity(unlocked ? 0.8 : 0.28),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${achievement.current.clamp(0, achievement.target)} / ${achievement.target}',
            style: GoogleFonts.spaceMono(
              fontSize: 9,
              color: Colors.white.withOpacity(unlocked ? 0.48 : 0.25),
            ),
          ),
        ],
      ),
    );
  }
}
