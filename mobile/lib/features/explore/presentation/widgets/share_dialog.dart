import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'mock_map.dart';

class ShareDialog extends StatefulWidget {
  const ShareDialog({super.key});
  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  String _category = 'Food';
  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                height: 210,
                child: MockMap(
                    child: Stack(children: [
                  Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14)),
                        child: const Row(children: [
                          Icon(Icons.search, size: 20),
                          SizedBox(width: 8),
                          Expanded(child: Text('Bếp cô Ba ân'))
                        ]),
                      )),
                  const Align(
                      alignment: Alignment(0, .5), child: HeartMapPin()),
                ]))),
            Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _category,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: ['Study Cafe', 'Entertainment', 'Food']
                            .map((category) => DropdownMenuItem(
                                value: category, child: Text(category)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _category = value ?? 'Food'),
                      ),
                      const SizedBox(height: 16),
                      const TextField(
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration:
                              InputDecoration(hintText: 'Add description')),
                      const SizedBox(height: 20),
                      Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            // Mock sharing only; no content is uploaded.
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                foregroundColor: Colors.white),
                            child: const Text('Share'),
                          )),
                    ])),
          ])),
        ),
      );
}
