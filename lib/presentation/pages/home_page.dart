import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/logic/shorts_provider.dart';
import 'package:ofgconnects/logic/video_provider.dart';
import 'package:ofgconnects/presentation/theme/ofg_ui.dart';
import 'package:ofgconnects/presentation/widgets/animate_in_effect.dart';
import 'package:ofgconnects/presentation/widgets/feed_ad_card.dart';
import 'package:ofgconnects/presentation/widgets/shorts_card.dart';
import 'package:ofgconnects/presentation/widgets/video_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scrollController = ScrollController();
  final _shortsScrollController = ScrollController();
  int _selectedChip = 0;

  static const _chips = ['All', 'Sermons', 'Music', 'Kids', 'Live'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        ref.read(videosListProvider.notifier).fetchMore();
      }
    });

    _shortsScrollController.addListener(() {
      if (_shortsScrollController.position.pixels >=
          _shortsScrollController.position.maxScrollExtent - 100) {
        ref.read(shortsListProvider.notifier).fetchMore();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shortsListProvider.notifier).fetchFirstBatch();
      ref.read(videosListProvider.notifier).fetchFirstBatch();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _shortsScrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(videosListProvider.notifier).refresh(),
      ref.read(shortsListProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final shortsState = ref.watch(shortsListProvider);
    final videosState = ref.watch(videosListProvider);
    const int adFrequency = 6;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: OfgUi.appBackground),
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: OfgUi.accent,
          backgroundColor: OfgUi.surface,
          edgeOffset: 60,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero()),
              SliverToBoxAdapter(child: _buildStats()),
              SliverToBoxAdapter(child: _buildCategoryChips()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: OfgUi.sectionHeader(
                    title: 'Shorts',
                    actionText: 'View All',
                    onActionTap: () => context.push('/shorts'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: (shortsState.items.isEmpty && shortsState.isLoadingMore)
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _shortsScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount:
                              shortsState.items.length + (shortsState.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == shortsState.items.length) {
                              return Center(
                                child: shortsState.isLoadingMore
                                    ? const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(),
                                      )
                                    : const SizedBox(width: 50),
                              );
                            }
                            return AnimateInEffect(
                              index: index,
                              child: SizedBox(
                                width: 170,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6),
                                  child: ShortsCard(video: shortsState.items[index]),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildFeaturedBanner()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: OfgUi.sectionHeader(title: 'Recommended'),
                ),
              ),
              if (videosState.items.isEmpty && videosState.isLoadingMore)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (videosState.items.isEmpty)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 280,
                    child: Center(
                      child: Text(
                        'No videos found.',
                        style: TextStyle(color: OfgUi.muted2),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index > 0 && index % adFrequency == 0) {
                        return const FeedAdCard();
                      }

                      final int adsBefore = index ~/ adFrequency;
                      final int videoIndex = index - adsBefore;

                      if (videoIndex >= videosState.items.length) {
                        if (videosState.isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return const SizedBox(height: 100);
                      }

                      return AnimateInEffect(
                        index: index,
                        child: VideoCard(video: videosState.items[videoIndex]),
                      );
                    },
                    childCount:
                        videosState.items.length + (videosState.items.length ~/ adFrequency) + 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: const BoxDecoration(gradient: OfgUi.heroGradient),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x663A6FC0), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x33D9522A), Colors.transparent],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x332D5AA0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x663A6FC0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF7AABF0)),
                      SizedBox(width: 6),
                      Text(
                        'TODAY IN FAITH',
                        style: TextStyle(
                          color: Color(0xFF7AABF0),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Grow Daily\nWith OFG Connects',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 30,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: OfgUi.text,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sermons, worship music, shorts, and kids content curated for your walk.',
                  style: TextStyle(color: OfgUi.muted2, fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: OfgUi.border),
      ),
      child: const Row(
        children: [
          Expanded(child: _StatCell(value: '24K', label: 'Members')),
          Expanded(child: _StatCell(value: '1.2K', label: 'Live Today')),
          Expanded(child: _StatCell(value: '680+', label: 'New Uploads')),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final selected = _selectedChip == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedChip = index);
              if (_chips[index] == 'Music') {
                context.push('/music');
              }
              if (_chips[index] == 'Kids') {
                context.push('/kids');
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? OfgUi.accent : OfgUi.surface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? OfgUi.accentHover : OfgUi.border,
                ),
              ),
              child: Text(
                _chips[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : OfgUi.muted2,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _chips.length,
      ),
    );
  }

  Widget _buildFeaturedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x663A6FC0)),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2040), Color(0xFF1E3060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x442D5AA0),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7AABF0)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Featured Stream',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Join tonight\'s worship and prayer session live.',
                  style: TextStyle(color: OfgUi.muted2, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: OfgUi.accent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Watch', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Cinzel',
            color: OfgUi.accent,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: OfgUi.muted,
            fontSize: 9,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

