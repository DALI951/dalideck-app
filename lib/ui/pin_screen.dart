import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../i18n.dart';
import '../main.dart';
import '../services/pin_service.dart';

class PinScreen extends StatefulWidget {
  final String? storedHash;
  final VoidCallback onUnlocked;
  const PinScreen({super.key, this.storedHash, required this.onUnlocked});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  int _failures = 0;
  int _lockoutSecs = 0;
  Timer? _lockoutTimer;
  late AnimationController _shakeCtrl;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    LocalAuthentication().canCheckBiometrics.then((v) {
      if (mounted) setState(() => _biometricAvailable = v);
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  bool get _locked => _lockoutSecs > 0;

  void _onKey(String d) {
    if (_locked || _pin.length >= 6) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 6) _verify();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _verify() {
    if (PinService.verifyPin(_pin, widget.storedHash)) {
      widget.onUnlocked();
      if (mounted) Navigator.of(context).pop();
    } else {
      _failures++;
      _shakeCtrl.forward(from: 0);
      setState(() {
        _error = t('wrong_pin');
        _pin = '';
      });
      if (_failures >= 5) _startLockout();
    }
  }

  void _startLockout() {
    setState(() => _lockoutSecs = 30);
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockoutSecs--;
        if (_lockoutSecs <= 0) {
          _failures = 0;
          timer.cancel();
        }
      });
    });
  }

  void _tryBiometric() async {
    final auth = LocalAuthentication();
    final didAuth = await auth.authenticate(
      localizedReason: t('enter_pin'),
      options: const AuthenticationOptions(stickyAuth: true),
    );
    if (didAuth) {
      widget.onUnlocked();
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() => _error = t('biometric_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.lock_outline, color: kMuted, size: 48),
            const SizedBox(height: 16),
            Text(t('enter_pin'),
                style: const TextStyle(color: kMuted, fontSize: 14)),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _shakeCtrl,
              builder: (context, child) {
                final offset =
                    (_shakeCtrl.value * 2 - 1) * 12 * (1 - _shakeCtrl.value);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? kAccent : kMuted.withOpacity(0.3),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: kAccent, fontSize: 13))
            else if (_locked)
              Text('${t('too_many_attempts')} $_lockoutSecs',
                  style: const TextStyle(color: kAccent, fontSize: 13)),
            const Spacer(),
            if (_biometricAvailable) ...[
              const SizedBox(height: 8),
              IconButton(
                onPressed: _locked ? null : _tryBiometric,
                icon: const Icon(Icons.fingerprint, size: 36, color: kAccent),
                tooltip: t('use_biometric'),
              ),
              const SizedBox(height: 4),
            ],
            _buildNumpad(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '⌫'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((d) {
                  if (d.isEmpty) return const SizedBox(width: 64, height: 52);
                  return SizedBox(
                    width: 64,
                    height: 52,
                    child: d == '⌫'
                        ? IconButton(
                            onPressed: _backspace,
                            icon: const Icon(Icons.backspace_outlined,
                                color: kMuted),
                          )
                        : OutlinedButton(
                            onPressed: () => _onKey(d),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kMuted),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(d,
                                style: const TextStyle(
                                    fontSize: 20, color: Colors.white)),
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
