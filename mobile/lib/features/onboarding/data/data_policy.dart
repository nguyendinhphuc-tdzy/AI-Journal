/// Where OB06's data copy comes from. Only the product team edits this, and
/// only with wording that matches the real architecture and policy; agents
/// must not write privacy claims (on-device only, encrypted, never used for
/// training…) that have not been confirmed.
///
/// Today nothing is approved: entries are kept on the device
/// (`LocalJournalRepository`) and AI reflections are a deterministic mock
/// (ADR-005), so the copy below says exactly that, under a clear
/// "Bản thử nghiệm" label. Update it when the backend store is wired.
class DataPolicy {
  const DataPolicy({
    required this.approved,
    required this.version,
    required this.storage,
    required this.aiRequest,
    required this.policyUrl,
  });

  /// False while the copy describes a demo build, not an approved policy.
  final bool approved;

  /// Policy version to record with the AI choice; null until there is one.
  final String? version;

  /// "Nhật ký của bạn": where entries are kept, per the real configuration.
  final String storage;

  /// "Khi yêu cầu phản hồi AI": what is sent and who processes it.
  final String aiRequest;

  /// "Cách app dùng dữ liệu"; the link is hidden while null (never a fake).
  final Uri? policyUrl;

  /// The build's policy. Replace with the approved copy before release.
  static const current = DataPolicy(
    approved: false,
    version: null,
    storage: 'Bản thử nghiệm lưu nhật ký trên máy này, chưa gửi lên máy chủ. '
        'Nơi lưu chính thức sẽ được ghi rõ ở đây trước khi phát hành.',
    aiRequest: 'Phản hồi trong bản thử nghiệm là mô phỏng: nội dung bạn viết '
        'không được gửi tới dịch vụ AI nào.',
    policyUrl: null,
  );

  static const choiceNote =
      'Bạn vẫn có thể viết và lưu nhật ký khi không dùng phản hồi AI.';
}
