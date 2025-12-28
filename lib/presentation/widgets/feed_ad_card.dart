import 'dart:io'; // Recommended for Platform checks
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class FeedAdCard extends StatefulWidget {
  const FeedAdCard({super.key});

  @override
  State<FeedAdCard> createState() => _FeedAdCardState();
}

class _FeedAdCardState extends State<FeedAdCard> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _hasLoadError = false; // Track errors

  // FIX: Swapped to Test ID to match comment and prevent AdMob policy violations during dev.
  // Real Android ID: 'ca-app-pub-1608316244906634/9732492112'
  final String _adUnitId = Platform.isAndroid 
      ? 'ca-app-pub-3940256099942544/6300978111' // Google Test ID (Safe for Dev)
      : 'ca-app-pub-3940256099942544/2934735716'; // Google iOS Test ID

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.mediumRectangle, 
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _hasLoadError = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad load failed: $error');
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _hasLoadError = true;
            });
          }
          ad.dispose();
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. If Ad is loaded, show it
    if (_isAdLoaded && _bannerAd != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.yellow, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "Ad",
                      style: TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text("Sponsored Content", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Center(
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
          ],
        ),
      );
    }

    // 2. If Ad failed, show a Red Box (For Debugging only)
    if (_hasLoadError) {
      return Container(
        height: 100,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red),
        ),
        child: const Center(
          child: Text(
            "Ad Failed to Load\nCheck Console Logs",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // 3. If Loading, show a Skeleton Box (So you know the slot exists)
    return Container(
      height: 250,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text("Loading Ad...", style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}