import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/antigravity_account.dart';
import '../models/provider_quota.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/request_activity.dart';

class AntigravityDetailScreen extends StatelessWidget {
  const AntigravityDetailScreen({required this.account, super.key});

  final AntigravityAccount account;

  @override
  Widget build(BuildContext context) {
    final hasError = account.quota.hasError;
    final statusColor = hasError ? AppTheme.danger : AppTheme.success;
    final auth = account.auth;

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                title: Text('账号详情'),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 38),
                sliver: SliverList.list(
                  children: [
                    GlassCard(
                      borderColor: statusColor.withValues(alpha: 0.34),
                      child: Column(
                        children: [
                          Hero(
                            tag: 'antigravity-${auth.id}',
                            child: GradientIcon(
                              icon: hasError
                                  ? Icons.cloud_off_rounded
                                  : Icons.auto_awesome_rounded,
                              size: 68,
                              iconSize: 34,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            auth.name.isEmpty ? '未命名账号' : auth.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (auth.email.isNotEmpty && auth.email != auth.name) ...[
                            const SizedBox(height: 5),
                            Text(
                              auth.email,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              StatusPill(
                                label: hasError ? '检查失败' : '可用',
                                color: statusColor,
                              ),
                              const StatusPill(
                                label: 'ANTIGRAVITY',
                                color: AppTheme.cyan,
                                icon: Icons.auto_awesome_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (hasError)
                      _ErrorCard(message: '${account.quota.error}')
                    else
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionTitle(
                              title: '额度窗口',
                              subtitle: 'Google Antigravity 各额度组独立计算',
                            ),
                            const SizedBox(height: 24),
                            for (var i = 0;
                                i < account.quota.windows.length;
                                i++) ...[
                              if (i > 0) const SizedBox(height: 20),
                              _AntigravityQuotaProgress(
                                window: account.quota.windows[i],
                              ),
                            ],
                            if (account.quota.windows.any((w) => w.resetAt != null)) ...[
                              const SizedBox(height: 24),
                              const Divider(height: 1),
                              const SizedBox(height: 20),
                              _AntigravityResetTimeline(
                                windows: account.quota.windows,
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(title: '认证信息'),
                          const SizedBox(height: 16),
                          _InfoRow(label: '认证 ID', value: auth.id),
                          const Divider(height: 24),
                          _InfoRow(label: 'Auth Index', value: auth.authIndex),
                          if (auth.successRequests > 0 || auth.failedRequests > 0) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              label: '成功请求',
                              value: '${auth.successRequests}',
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              label: '失败请求',
                              value: '${auth.failedRequests}',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AntigravityQuotaProgress extends StatelessWidget {
  const _AntigravityQuotaProgress({required this.window});

  final ProviderQuotaWindow window;

  @override
  Widget build(BuildContext context) {
    final remaining = window.remainingPercent;
    final color = _quotaColor(remaining);
    final target = remaining == null ? 0.0 : remaining / 100;

    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: target.clamp(0.0, 1.0).toDouble(),
        end: target.clamp(0.0, 1.0).toDouble(),
      ),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  window.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                child: Text(
                  remaining == null
                      ? '--'
                      : '可用 ${remaining.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0x221B2947),
              borderRadius: BorderRadius.circular(99),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.72), color],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          ResetCountdown(target: window.resetAt),
        ],
      ),
    );
  }

  static Color _quotaColor(double? remaining) {
    if (remaining == null) return const Color(0xFF75829B);
    if (remaining <= 15) return AppTheme.danger;
    if (remaining <= 35) return AppTheme.warning;
    return AppTheme.cyan;
  }
}

class _AntigravityResetTimeline extends StatelessWidget {
  const _AntigravityResetTimeline({required this.windows});

  final List<ProviderQuotaWindow> windows;

  @override
  Widget build(BuildContext context) {
    final events = windows
        .where((w) => w.resetAt != null)
        .map(
          (w) => _ResetTimelineEntry(
            label: w.label,
            time: w.resetAt!,
            color: w.label.contains('Gemini') ? AppTheme.cyan : AppTheme.violet,
            icon: w.label.contains('5H')
                ? Icons.bolt_rounded
                : Icons.calendar_month_rounded,
          ),
        )
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('quota-reset-timeline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timeline_rounded, color: AppTheme.cyan, size: 18),
            const SizedBox(width: 9),
            Text(
              '重置时间轴',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 15),
            ),
            const Spacer(),
            const Text(
              'NEXT WINDOWS',
              style: TextStyle(
                color: Color(0xFF6F7E96),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < events.length; index++)
          _ResetTimelineItem(
            event: events[index],
            isLast: index == events.length - 1,
          ),
      ],
    );
  }
}

class _ResetTimelineEntry {
  const _ResetTimelineEntry({
    required this.label,
    required this.time,
    required this.color,
    required this.icon,
  });

  final String label;
  final DateTime time;
  final Color color;
  final IconData icon;
}

class _ResetTimelineItem extends StatelessWidget {
  const _ResetTimelineItem({required this.event, required this.isLast});

  final _ResetTimelineEntry event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final time = event.time.toLocal();
    final absoluteTime = DateFormat('M月d日 HH:mm').format(time);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Column(
            children: [
              Container(
                width: 18,
                height: 18,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: event.color.withValues(alpha: 0.12),
                  border: Border.all(color: event.color.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: event.color.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: event.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 66,
                  color: event.color.withValues(alpha: 0.25),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: event.color.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(event.icon, color: event.color, size: 15),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        event.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      absoluteTime,
                      style: TextStyle(
                        color: event.color.withValues(alpha: 0.92),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ResetCountdown(target: time, prefix: '剩余'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.danger.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: '额度查询失败'),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: Color(0xFFFFA1B5))),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: SelectableText(
            value.isEmpty ? '--' : value,
            style: TextStyle(color: valueColor ?? const Color(0xFFDCE5F7)),
          ),
        ),
      ],
    );
  }
}
