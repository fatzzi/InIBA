import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_controller.dart';
import '../widgets/error_text.dart';

/// Wireframes 1.4 + 1.5 (SCRUM-24 screen, SCRUM-25 behaviour).
///
/// - 6 boxes, digits only; typing moves to the next box, clearing moves back,
///   and pasting the whole code fills every box.
/// - Verifies automatically once all 6 digits are in (the button works too).
/// - "Resend code" unlocks after a 60 s cooldown (same as the backend's
///   OTP_RESEND_COOLDOWN_SECONDS); if the backend says to wait longer, the
///   countdown uses its number.
/// - Errors: wrong/expired code clears the boxes; 5 wrong tries locks Verify
///   until a new code is requested.
/// - On success the router goes to Profile Setup (first login) or the Main Feed.
class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key, required this.email});
  final String email;

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  static const _len = 6;
  static const resendCooldownSeconds = 60;

  final _controllers = List.generate(_len, (_) => TextEditingController());
  final _nodes = List.generate(_len, (_) => FocusNode());
  Timer? _timer;
  int _secondsLeft = resendCooldownSeconds;
  bool _locked = false; // too many wrong tries: only a new code helps
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCooldown(resendCooldownSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
      if (_secondsLeft == 0) t.cancel();
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _setBox(int i, String digit) {
    _controllers[i].value = TextEditingValue(
      text: digit,
      selection: TextSelection.collapsed(offset: digit.length),
    );
  }

  void _clearBoxes() {
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
  }

  void _onChanged(int i, String value) {
    final auth = ref.read(authProvider.notifier);
    if (ref.read(authProvider).error != null && !_locked) auth.clearError();

    if (value.length > 2) {
      // Pasted the whole code (or part of it): spread it over the boxes.
      final digits = value.split('');
      for (var k = 0; k < digits.length && i + k < _len; k++) {
        _setBox(i + k, digits[k]);
      }
      final next = (i + digits.length).clamp(0, _len - 1);
      _nodes[next].requestFocus();
    } else if (value.length == 2) {
      // Typed over a box that already had a digit: keep the new one.
      _setBox(i, value.substring(1));
      if (i < _len - 1) _nodes[i + 1].requestFocus();
    } else if (value.length == 1) {
      if (i < _len - 1) _nodes[i + 1].requestFocus();
    } else if (i > 0) {
      _nodes[i - 1].requestFocus(); // cleared a box: step back
    }

    setState(() {});
    if (_code.length == _len) _verify();
  }

  Future<void> _verify() async {
    final auth = ref.read(authProvider);
    if (_code.length != _len || auth.isLoading || _locked) return;

    final failure = await ref
        .read(authProvider.notifier)
        .verifyOtp(widget.email, _code);
    if (!mounted || failure == null) return; // success: router redirects

    setState(() => _locked = failure == 429);
    if (failure == 400 || failure == 429) _clearBoxes();
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    final error = await ref
        .read(authProvider.notifier)
        .resendOtp(widget.email);
    if (!mounted) return;
    setState(() => _resending = false);

    if (error == null) {
      setState(() => _locked = false);
      _clearBoxes();
      _startCooldown(resendCooldownSeconds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A new code was sent to ${widget.email}')),
      );
    } else if (error.retryAfterSeconds != null) {
      _startCooldown(error.retryAfterSeconds!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;
    final hasError = auth.error != null;
    final m = (_secondsLeft ~/ 60).toString();
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    final canVerify = !auth.isLoading && !_locked && _code.length == _len;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the 6-digit code we sent to',
                textAlign: TextAlign.center,
              ),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_len, (i) {
                  return Container(
                    width: 44,
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      key: Key('otp-$i'),
                      controller: _controllers[i],
                      focusNode: _nodes[i],
                      autofocus: i == 0,
                      enabled: !_locked,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: i == 0
                          ? const [AutofillHints.oneTimeCode]
                          : null,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_len),
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: hasError ? scheme.error : scheme.outline,
                          ),
                        ),
                      ),
                      onChanged: (v) => _onChanged(i, v),
                    ),
                  );
                }),
              ),
              if (hasError)
                Center(
                  key: const Key('otp-error'),
                  child: ErrorText(auth.error),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('verify-button'),
                onPressed: canVerify ? _verify : null,
                child: auth.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),
              const SizedBox(height: 16),
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        "Didn't get it? Resend code in $m:$s",
                        key: const Key('resend-countdown'),
                        style: const TextStyle(color: Colors.grey),
                      )
                    : TextButton(
                        key: const Key('resend-button'),
                        onPressed: _resending ? null : _resend,
                        child: Text(_resending ? 'Sending...' : 'Resend code'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
