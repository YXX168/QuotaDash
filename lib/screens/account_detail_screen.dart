import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/codex_account.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/quota_progress.dart';
import '../widgets/request_activity.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({required this.account, super.key});

  final CodexAccount account;

  @override
  Widget build(BuildContext context) {
    final statusColor = account.hasError
        ? AppTheme.danger
        : account.isAvailable
        ? AppTheme.success
        : AppTheme.warning;
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                title: const Text('账号详情'),
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
                            tag: 'account-${account.id}',
                            child: GradientIcon(
                              icon: account.hasError
                                  ? Icons.cloud_off_rounded
                                  : Icons.smart_toy_rounded,
                              size: 68,
                              iconSize: 34,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            account.name.isEmpty ? '未命名账号' : account.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (account.email.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              account.email,
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
                                label: account.hasError
                                    ? '检查失败'
                                    : account.isAvailable
                                    ? '可用'
                                    : '受限',
                                color: statusColor,
                              ),
                              StatusPill(
                                label: account.plan.toUpperCase(),
                                color: AppTheme.cyan,
                                icon: Icons.workspace_premium_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (account.hasError)
                      _ErrorCard(message: account.error!)
                    else
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionTitle(
                              title: '额度窗口',
                              subtitle: '数据来自 ChatGPT Codex usage API',
                            ),
                            const SizedBox(height: 24),
                            QuotaProgress(
                              label: account.primaryLabel,
                              window: account.primary,
                            ),
                            if (account.secondary != null) ...[
                              const SizedBox(height: 25),
                              QuotaProgress(
                                label: account.secondaryLabel,
                                window: account.secondary,
                              ),
                            ],
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 20),
                            _ResetTimeline(account: account),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    _ActivityCard(account: account),
                    const SizedBox(height: 18),
                    _MetricsCard(account: account),
                    const SizedBox(height: 18),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(title: '认证信息'),
                          const SizedBox(height: 16),
                          _InfoRow(label: '认证 ID', value: account.id),
                          const Divider(height: 24),
                          _InfoRow(
                            label: 'Auth Index',
                            value: account.authIndex,
                          ),
                          if (account.resetCreditsError != null) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              label: '重置额度状态',
                              value: account.resetCreditsError!,
                              valueColor: AppTheme.warning,
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

class _ResetTimeline extends StatelessWidget {
  const _ResetTimeline({required this.account});

  final CodexAccount account;

  @override
  Widget build(BuildContext context) {
    final events = <_ResetEvent>[];
    if (account.primary != null) {
      events.add(
        _ResetEvent(
          label: account.primaryLabel,
          time: account.primary?.resetAt,
          color: AppTheme.cyan,
          icon: Icons.bolt_rounded,
        ),
      );
    }
    if (account.secondary != null) {
      events.add(
        _ResetEvent(
          label: account.secondaryLabel,
          time: account.secondary?.resetAt,
          color: AppTheme.success,
          icon: Icons.calendar_month_rounded,
        ),
      );
    }
    events.sort((left, right) {
      if (left.time == null && right.time == null) return 0;
      if (left.time == null) return 1;
      if (right.time == null) return -1;
      return left.time!.compareTo(right.time!);
    });
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

class _ResetTimelineItem extends StatelessWidget {
  const _ResetTimelineItem({required this.event, required this.isLast});

  final _ResetEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final time = event.time?.toLocal();
    final absoluteTime = time == null
        ? '时间未知'
        : DateFormat('M月d日 HH:mm').format(time);
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

class _ResetEvent {
  const _ResetEvent({
    required this.label,
    required this.time,
    required this.color,
    required this.icon,
  });

  final String label;
  final DateTime? time;
  final Color color;
  final IconData icon;
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.account});

  final CodexAccount account;

  @override
  Widget build(BuildContext context) {
    final successRate = account.successRate;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '请求趋势',
            subtitle: account.recentRequests.isEmpty
                ? '当前服务端没有返回近期时间桶'
                : '最近 ${account.recentRequests.length} 个统计窗口',
            trailing: Text(
              successRate == null
                  ? '--'
                  : '${successRate.toStringAsFixed(1)}% 成功',
              style: TextStyle(
                color: successRate != null && successRate < 90
                    ? AppTheme.warning
                    : AppTheme.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          RequestSparkline(buckets: account.recentRequests, height: 92),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActivityMetric(
                label: '近期请求',
                value: '${account.recentTotal}',
                color: AppTheme.cyan,
              ),
              const SizedBox(width: 9),
              _ActivityMetric(
                label: '近期成功',
                value: '${account.recentSuccess}',
                color: AppTheme.success,
              ),
              const SizedBox(width: 9),
              _ActivityMetric(
                label: '近期失败',
                value: '${account.recentFailed}',
                color: account.recentFailed == 0
                    ? AppTheme.success
                    : AppTheme.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.account});

  final CodexAccount account;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(
        label: '成功请求',
        value: '${account.successRequests}',
        icon: Icons.check_circle_rounded,
        color: AppTheme.success,
      ),
      _Metric(
        label: '失败请求',
        value: '${account.failedRequests}',
        icon: Icons.cancel_rounded,
        color: account.failedRequests == 0 ? AppTheme.cyan : AppTheme.danger,
      ),
      _Metric(
        label: '主动重置',
        value: account.resetCredits?.toString() ?? '--',
        icon: Icons.bolt_rounded,
        color: AppTheme.success,
      ),
    ];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: '账号统计'),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: metrics[index]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
