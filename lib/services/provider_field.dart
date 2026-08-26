import 'package:flutter/material.dart';

/// Declarative description of one configuration input owned by a provider
/// module. The config screen renders these fields dynamically so new
/// providers never require UI changes.
class ProviderField {
  const ProviderField({
    required this.key,
    required this.label,
    this.hint,
    this.obscure = false,
    this.required = false,
    this.keyboardType,
  });

  /// Stable storage key inside [AppConfig.values].
  final String key;

  /// Label rendered above the input.
  final String label;

  /// Optional placeholder text.
  final String? hint;

  /// Whether the value should be masked (API keys, passwords).
  final bool obscure;

  /// Whether the module cannot run without this field filled in.
  final bool required;

  final TextInputType? keyboardType;
}
