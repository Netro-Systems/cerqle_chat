import '../../configuration/cerqle_config.dart';
import '../../domain/errors/cerqle_exception.dart';
import '../../domain/models/models.dart';

/// Validates backend-required pre-chat fields without transport/UI concerns.
final class PreChatValidator {
  const PreChatValidator();

  bool isSatisfiedBy(CerqleWidgetConfig widget, CerqleUser? user) {
    if (user == null) return false;
    for (final field in widget.preChatFields) {
      switch (field) {
        case CerqlePreChatField.name:
          if (user.name?.trim().isNotEmpty != true) return false;
        case CerqlePreChatField.email:
          if (user.email?.trim().isNotEmpty != true) return false;
        case CerqlePreChatField.unknown:
          return false;
      }
    }
    return true;
  }

  void validateConfiguration(CerqleWidgetConfig widget) {
    if (widget.requiresPreChat &&
        widget.preChatFields.contains(CerqlePreChatField.unknown)) {
      throw const CerqleException(
        code: CerqleErrorCode.unsupported,
        message: 'This widget requires an unsupported pre-chat field.',
        retryable: false,
      );
    }
  }

  void validateSubmission(CerqleWidgetConfig widget, CerqlePreChatData data) {
    final name = data.name?.trim() ?? '';
    final email = data.email?.trim() ?? '';
    if (widget.preChatFields.contains(CerqlePreChatField.name) &&
        name.isEmpty) {
      throw const CerqleException(
        code: CerqleErrorCode.validation,
        message: 'Name is required.',
        retryable: false,
        fieldErrors: <String, List<String>>{
          'name': <String>['Name is required.'],
        },
      );
    }
    if (name.length > 120) {
      throw const CerqleException(
        code: CerqleErrorCode.validation,
        message: 'Name must be 120 characters or fewer.',
        retryable: false,
      );
    }
    if (widget.preChatFields.contains(CerqlePreChatField.email) &&
        email.isEmpty) {
      throw const CerqleException(
        code: CerqleErrorCode.validation,
        message: 'Email is required.',
        retryable: false,
        fieldErrors: <String, List<String>>{
          'email': <String>['Email is required.'],
        },
      );
    }
    if (email.length > 190 ||
        (email.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      throw const CerqleException(
        code: CerqleErrorCode.validation,
        message: 'Enter a valid email address.',
        retryable: false,
        fieldErrors: <String, List<String>>{
          'email': <String>['Enter a valid email address.'],
        },
      );
    }
  }
}
