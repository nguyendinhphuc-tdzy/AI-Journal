import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key, this.onShare});
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          Text('Album', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          const Text('Little moments to keep.'),
          const SizedBox(height: 24),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AspectRatio(
                          aspectRatio: 2,
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(16))),
                              child: Icon(Icons.restaurant_outlined,
                                  size: 56, color: AppColors.primaryDark))),
                      const SizedBox(height: 16),
                      Text('Bếp cô Ba ân',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text('A warm meal and a quiet afternoon.'),
                      const SizedBox(height: 16),
                      Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: onShare,
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                          )),
                    ])),
          ),
        ])),
      );
}
