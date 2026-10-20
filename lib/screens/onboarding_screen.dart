import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_constants.dart';
import 'auth_gate.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _navigationTimer = Timer(const Duration(seconds: 3), _goHome);
  }

  void _goHome() {
    _navigationTimer?.cancel();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goHome,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF25123D),
                Color(0xFF100C1B),
                Color(0xFF07060D),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final v = _animationController.value;

                        return Transform.scale(
                          scale: 1 + (v * 0.12),
                          child: Container(
                            height: 145,
                            width: 145,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.purple
                                  .withValues(alpha: 0.10 + v * 0.10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.purple
                                      .withValues(alpha: 0.15 + v * 0.20),
                                  blurRadius: 45,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.hourglass_top_rounded,
                              color: Color(0xFFE1CFFF),
                              size: 78,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 38),
                    const Text(
                      'TimeCapsule',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Save today. Meet tomorrow.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        color: Color(0xFFD5C2F8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your memories deserve their own moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 55),
                    const SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Color(0xFF352744),
                        color: AppColors.purple,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Every moment becomes a memory...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}