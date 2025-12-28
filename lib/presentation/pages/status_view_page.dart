import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/models/status.dart';

class StatusViewPage extends StatefulWidget {
  final List<Status> statuses;
  const StatusViewPage({super.key, required this.statuses});

  @override
  State<StatusViewPage> createState() => _StatusViewPageState();
}

class _StatusViewPageState extends State<StatusViewPage> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStatus();
      }
    });

    _animController.forward();
  }

  void _nextStatus() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() {
        _currentIndex++;
        _pageController.animateToPage(_currentIndex, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        _animController.reset();
        _animController.forward();
      });
    } else {
      context.pop(); // Close viewer when done
    }
  }

  void _prevStatus() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pageController.animateToPage(_currentIndex, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        _animController.reset();
        _animController.forward();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.statuses[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _prevStatus();
          } else {
            _nextStatus();
          }
        },
        onLongPressStart: (_) => _animController.stop(),
        onLongPressEnd: (_) => _animController.forward(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              status.contentUrl,
              fit: BoxFit.contain,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
            ),
            if (status.caption != null && status.caption!.isNotEmpty)
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Text(status.caption!, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                ),
              ),
            Positioned(
              top: 40,
              left: 10,
              right: 10,
              child: Column(
                children: [
                  Row(
                    children: List.generate(widget.statuses.length, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.white30,
                          ),
                          child: index == _currentIndex 
                            ? AnimatedBuilder(
                                animation: _animController,
                                builder: (context, child) => FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _animController.value,
                                  child: Container(color: Colors.white),
                                ),
                              )
                            : Container(color: index < _currentIndex ? Colors.white : Colors.transparent),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: (status.userAvatar != null) ? NetworkImage(status.userAvatar!) : null,
                        child: (status.userAvatar == null) ? Text(status.username[0]) : null,
                      ),
                      const SizedBox(width: 10),
                      Text(status.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}