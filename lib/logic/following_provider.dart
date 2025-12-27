import 'package:riverpod_annotation/riverpod_annotation.dart';

// This line is CRITICAL. It tells Riverpod to generate the code here.
part 'following_provider.g.dart'; 

@riverpod
class PaginatedFollowing extends _$PaginatedFollowing {
  @override
  AsyncValue<List<dynamic>> build() {
    return const AsyncValue.data([]);
  }

  Future<void> fetchFirstBatch() async {
    state = const AsyncValue.loading();
    // Your Appwrite logic to fetch followers goes here
    // state = AsyncValue.data(fetchedList);
  }

  Future<void> fetchMore() async {
    // Your logic to append more users
  }
}