import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 1. IMPORT YOUR PROVIDER FILE HERE
import 'package:ofgconnects_mobile/logic/following_provider.dart'; 

class FollowingPage extends ConsumerStatefulWidget {
  const FollowingPage({super.key});

  @override
  ConsumerState<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends ConsumerState<FollowingPage> {
  @override
  void initState() {
    super.initState();
    // 2. THIS WILL NOW WORK AFTER GENERATION
    Future.microtask(() =>
      ref.read(paginatedFollowingProvider.notifier).fetchFirstBatch()
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3. WATCH THE GENERATED PROVIDER
    final followingState = ref.watch(paginatedFollowingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Following")),
      body: followingState.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => ListTile(title: Text(list[index].toString())),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}