import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_lpg_app/pages/login_page.dart';
import 'package:smart_lpg_app/pages/home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // 🔥 After delay, check auth state and navigate accordingly
    Timer(const Duration(seconds: 3), () {
      _navigateBasedOnAuth();
    });
  }

  // 🔥 Check Firebase Auth and route accordingly
  void _navigateBasedOnAuth() {
    final User? user = FirebaseAuth.instance.currentUser;

    final route = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          user != null ? HomePage() : LoginPage(), // ✅ auth check here
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 800),
    );

    Navigator.of(context).pushReplacement(route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF3A7BD5),
                Color(0xFF00D2FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // 🔥 Icon Box
              Container(
                padding: EdgeInsets.all(size.width * 0.05),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(size.width * 0.05),
                ),
                child: Icon(
                  Icons.local_fire_department,
                  size: size.width * 0.12,
                  color: const Color(0xFF2D6CDF),
                ),
              ),

              SizedBox(height: size.height * 0.03),

              // 📝 Title
              Text(
                "Smart LPG",
                style: TextStyle(
                  fontSize: size.width * 0.07,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: size.height * 0.01),

              // 📄 Subtitle
              Text(
                "Intelligent Gas Monitoring System",
                style: TextStyle(
                  fontSize: size.width * 0.03,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),

              SizedBox(height: size.height * 0.05),

              // 🔄 Animated Dots
              const AnimatedDots(),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔄 Animated Dots Widget (unchanged)
class AnimatedDots extends StatefulWidget {
  const AnimatedDots({super.key});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {

  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        double opacity =
            ((_dotController.value + index * 0.3) % 1.0).clamp(0.3, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDot(0),
        _buildDot(1),
        _buildDot(2),
      ],
    );
  }
}