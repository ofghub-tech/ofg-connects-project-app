// lib/presentation/widgets/animate_in_effect.dart
import 'package:flutter/material.dart';

class AnimateInEffect extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;

  const AnimateInEffect({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<AnimateInEffect> createState() => _AnimateInEffectState();
}

class _AnimateInEffectState extends State<AnimateInEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Stagger delay based on index (0ms, 100ms, 200ms...)
    Future.delayed(Duration(milliseconds: (widget.index % 10) * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}