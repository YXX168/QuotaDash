import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_config.dart';
import '../services/config_store.dart';
import '../services/provider_field.dart';
import '../services/provider_registry.dart';
import '../services/quota_module.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({
    required this.configStore,
    required this.onSaved,
    super.key,
    this.initialConfig,
    this.loadError,
    this.popOnSave = false,
    this.registry = ProviderRegistry.defaultRegistry,
  });

  final ConfigStore configStore;
  final AppConfig? initialConfig;
  final String? loadError;
  final bool popOnSave;
  final ProviderRegistry registry;
  final Future<void> Function(AppConfig config) onSaved;

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final List<QuotaModule> _modules;
  late final Map<String, TextEditingController> _fieldControllers;
  late final AnimationController _entryController;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _modules = widget.registry.modules;
    _fieldControllers = {
      for (final module in _modules)
        for (final field in module.fields)
          field.key: TextEditingController(
            text: _displayValue(field, widget.initialConfig),
          ),
    };
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _displayValue(ProviderField field, AppConfig? config) {
    final raw = config?.value(field.key) ?? '';
    if (field.key == 'baseUrl' && raw.isNotEmpty) {
      return _originOnly(raw);
    }
    return raw;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final values = {...?widget.initialConfig?.values};
    for (final entry in _fieldControllers.entries) {
      var value = entry.value.text.trim();
      if (entry.key == 'baseUrl') value = _managementUrl(value);
      if (value.isEmpty) {
        values.remove(entry.key);
      } else {
        values[entry.key] = value;
      }
    }
    final config = AppConfig(values: values);

    try {
      await widget.onSaved(config);
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      if (widget.popOnSave) Navigator.of(context).pop(config);
    } catch (error) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _saveError = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final animation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned(
                top: 52,
                right: -30,
                child: _ConfigDeco(color: AppTheme.violet),
              ),
              const Positioned(
                bottom: 60,
                left: -40,
                child: _ConfigDeco(flip: true, color: AppTheme.cyan),
              ),
              FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.025),
                    end: Offset.zero,
                  ).animate(animation),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (canPop)
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(Icons.arrow_back_rounded),
                                  ),
                                if (canPop) const SizedBox(width: 4),
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.cyan, AppTheme.violet],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x5538E8FF),
                                        blurRadius: 14,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.link_rounded,
                                    size: 19,
                                    color: AppTheme.background,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '连接配置',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontSize: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '按供应商分别填入连接信息；所有凭据仅保存在设备安全存储中。',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    for (final module in _modules) ...[
                                      _ModuleSectionHeader(module: module),
                                      const SizedBox(height: 10),
                                      for (
                                        var index = 0;
                                        index < module.fields.length;
                                        index++
                                      ) ...[
                                        if (index > 0)
                                          const SizedBox(height: 12),
                                        _ProviderFieldInput(
                                          field: module.fields[index],
                                          isModuleActive: () =>
                                              module.fields.any(
                                                (field) =>
                                                    _fieldControllers[field
                                                            .key]!
                                                        .text
                                                        .trim()
                                                        .isNotEmpty,
                                              ),
                                          controller:
                                              _fieldControllers[module
                                                  .fields[index]
                                                  .key]!,
                                          onSubmitted:
                                              index == module.fields.length - 1
                                              ? (_) => _save()
                                              : null,
                                        ),
                                      ],
                                      if (!identical(module, _modules.last))
                                        const SizedBox(height: 20),
                                    ],
                                    const SizedBox(height: 12),
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.shield_outlined,
                                          size: 15,
                                          color: AppTheme.success,
                                        ),
                                        SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            '管理地址与密码仅保存在设备安全存储中，不内置于 App。',
                                            style: TextStyle(
                                              color: Color(0xFF8F9BB1),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (widget.loadError != null ||
                                        _saveError != null) ...[
                                      const SizedBox(height: 14),
                                      _ErrorBanner(
                                        message:
                                            _saveError ??
                                            widget.loadError.toString(),
                                      ),
                                    ],
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: FilledButton(
                                        key: const Key('save-config-button'),
                                        onPressed: _saving ? null : _save,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          child: _saving
                                              ? const SizedBox.square(
                                                  key: ValueKey('saving'),
                                                  dimension: 19,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text(
                                                  '保存',
                                                  key: ValueKey('save'),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _normalizeUrl(String value) {
  return value.trim().replaceFirst(RegExp(r'/+$'), '');
}

String _managementUrl(String value) {
  final uri = Uri.parse(_normalizeUrl(value));
  const suffix = '/v0/management';
  final path = uri.path.endsWith(suffix)
      ? uri.path
      : '${uri.path.replaceFirst(RegExp(r'/+$'), '')}$suffix';
  return uri.replace(path: path, query: null, fragment: null).toString();
}

String _originOnly(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return value;
  const suffix = '/v0/management';
  final path = uri.path.endsWith(suffix)
      ? uri.path.substring(0, uri.path.length - suffix.length)
      : uri.path;
  return uri
      .replace(path: path, query: null, fragment: null)
      .toString()
      .replaceFirst(RegExp(r'/+$'), '');
}

String? _validateUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return '请输入完整地址';
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return '仅支持 HTTP 或 HTTPS';
  }
  if (uri.hasQuery || uri.hasFragment) return '地址不能包含参数或片段';
  return null;
}

class _ConfigDeco extends StatelessWidget {
  const _ConfigDeco({required this.color, this.flip = false});

  final Color color;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.flip(
        flipX: flip,
        child: CustomPaint(
          size: const Size(210, 170),
          painter: _ConfigDecoPainter(color),
        ),
      ),
    );
  }
}

class _ConfigDecoPainter extends CustomPainter {
  const _ConfigDecoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.82, size.height * 0.66);
    final arcRect = Rect.fromCircle(center: center, radius: 118);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.32),
          color.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: center, radius: 160));
    canvas.drawCircle(center, 160, glow);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.05), color.withValues(alpha: 0.55)],
      ).createShader(arcRect);
    canvas.drawArc(arcRect, 1.95, 1.35, false, arc);

    final fineArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.30);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 88),
      2.15,
      0.82,
      false,
      fineArc,
    );

    for (final point in const [Offset(24, 118), Offset(42, 26)]) {
      final dotColor = color.withValues(alpha: 0.75);
      canvas.drawCircle(point, 1.6, Paint()..color = dotColor);
      canvas.drawCircle(
        point,
        3.2,
        Paint()..color = color.withValues(alpha: 0.15),
      );
    }

    final dash = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.45);
    for (var t = 0; t < 4; t++) {
      final base = Offset(center.dx - 84 + t * 26, center.dy + 74);
      canvas.drawLine(base, base + const Offset(14, 0), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfigDecoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFFFA1B5))),
    );
  }
}

class _ModuleSectionHeader extends StatelessWidget {
  const _ModuleSectionHeader({required this.module});

  final QuotaModule module;

  @override
  Widget build(BuildContext context) {
    final accent = module.accentColor;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Icon(module.icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                module.displayName,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                module.description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderFieldInput extends StatefulWidget {
  const _ProviderFieldInput({
    required this.field,
    required this.controller,
    required this.isModuleActive,
    this.onSubmitted,
  });

  final ProviderField field;
  final TextEditingController controller;
  final bool Function() isModuleActive;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_ProviderFieldInput> createState() => _ProviderFieldInputState();
}

class _ProviderFieldInputState extends State<_ProviderFieldInput> {
  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    return TextFormField(
      key: Key('provider-field-${field.key}'),
      controller: widget.controller,
      obscureText: field.obscure,
      keyboardType: field.keyboardType,
      textInputAction: widget.onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      autocorrect: true,
      enableSuggestions: true,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: field.label + (field.required ? '' : '（可选）'),
        hintText: field.hint,
        prefixIcon: Icon(
          field.keyboardType == TextInputType.url
              ? Icons.link_rounded
              : Icons.key_rounded,
        ),
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (field.required && widget.isModuleActive() && trimmed.isEmpty) {
          return '请输入${field.label}';
        }
        if (field.key == 'baseUrl' &&
            trimmed.isNotEmpty &&
            _validateUrl(trimmed) != null) {
          return _validateUrl(trimmed);
        }
        return null;
      },
    );
  }
}
