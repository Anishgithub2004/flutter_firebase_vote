import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FingerprintRegistrationScreen extends StatefulWidget {
  const FingerprintRegistrationScreen({super.key});

  @override
  State<FingerprintRegistrationScreen> createState() =>
      _FingerprintRegistrationScreenState();
}

class _FingerprintRegistrationScreenState
    extends State<FingerprintRegistrationScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      setState(() {
        _isBiometricAvailable = canCheckBiometrics && isDeviceSupported;
      });
    } catch (e) {
      print('Error checking biometric availability: $e');
    }
  }

  Future<void> _registerFingerprint() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to register your fingerprint',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'hasBiometric': true,
            'biometricRegisteredAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fingerprint registered successfully'),
              ),
            );
            Navigator.pop(context);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fingerprint Registration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fingerprint,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              _isBiometricAvailable
                  ? 'Register your fingerprint for secure access'
                  : 'Biometric authentication is not available on this device',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (_isBiometricAvailable)
              ElevatedButton(
                onPressed: _registerFingerprint,
                child: const Text('Register Fingerprint'),
              ),
          ],
        ),
      ),
    );
  }
}
