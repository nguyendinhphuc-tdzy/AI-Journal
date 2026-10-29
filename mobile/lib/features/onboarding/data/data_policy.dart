import '../../../core/config/app_config.dart';

/// Where OB06's data copy comes from. Only the product team edits this, and
/// only with wording that matches the real architecture and policy; agents
/// must not write privacy claims (on-device only, encrypted, never used for
/// training…) that have not been confirmed.
///
/// Nothing is approved yet, so every version shows a "Bản thử nghiệm"
/// label: [current] for a build without AI (guests, the device-only demo),
/// [localOllama] for a signed-in account with the team's Ollama.
class DataPolicy {
  const DataPolicy({
    required this.approved,
    required this.version,
    required this.storage,
    required this.aiRequest,
    required this.policyUrl,
    this.realLocalAi = false,
    this.choice = choiceNote,
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

  /// True only when a configured authenticated local Ollama provider exists.
  final bool realLocalAi;

  /// "Quyền lựa chọn": what the user can still decide.
  final String choice;

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

  /// A signed-in account: AI is on in the app (product decision,
  /// 29/10/2026) and can be turned off in Hồ sơ. Version 3: AI is no longer
  /// a choice on this screen. Legacy explicit opt-outs remain off. Version
  /// 4: with cloud journals, analyses are kept on the server (PR #72).
  static const localOllama = DataPolicy(
    approved: false,
    version: 'local-ollama-demo-4',
    realLocalAi: true,
    storage: AppConfig.journalCloudEnabled
        ? 'Nhật ký mới được lưu trong tài khoản của bạn trên máy chủ nhóm. '
            'Các nhật ký cũ chỉ có trên máy vẫn ở máy này, không tự tải lên.'
        : 'Nhật ký được lưu trên thiết bị này, riêng cho tài khoản của bạn.',
    aiRequest:
        AppConfig.journalCloudEnabled ? aiRequestCloud : aiRequestDevice,
    policyUrl: null,
    choice: aiOffNote,
  );

  /// Cloud journals: the analysis is kept with the journal on the server
  /// (deleted with it); one made before stays on the device only.
  static const aiRequestCloud = 'Khi phản hồi AI đang bật, việc lưu nhật ký '
      'hoặc dùng Nhìn lại cùng bạn sẽ gửi nội dung liên quan qua FastAPI tới '
      'Ollama trên máy của nhóm để phân tích và gợi ý câu hỏi. Kết quả phân '
      'tích (gồm nhóm cảm xúc và điểm dùng cho biểu đồ tuần) và đánh giá của '
      'bạn được lưu trong tài khoản trên máy chủ nhóm, cùng bài viết; xóa bài '
      'thì phân tích bị xóa theo. Nhận xét tuần chỉ được tạo khi bạn bấm, từ '
      'số liệu tổng hợp, và cũng được lưu trong tài khoản. Phân tích tạo '
      'trước đây có thể chỉ có trên máy này. Điểm cảm xúc là quy ước hiển '
      'thị, không phải chẩn đoán.';

  /// Journals on the device: so are their analyses.
  static const aiRequestDevice = 'Khi phản hồi AI đang bật, việc lưu nhật ký '
      'hoặc dùng Nhìn lại cùng bạn sẽ gửi nội dung liên quan qua FastAPI tới '
      'Ollama trên máy của nhóm để phân tích và gợi ý câu hỏi. Kết quả phân '
      'tích và nhóm cảm xúc dùng cho biểu đồ tuần được lưu trên thiết bị theo '
      'tài khoản, không đồng bộ lên máy chủ: đổi máy hoặc xóa app có thể mất '
      'chúng. Điểm cảm xúc là quy ước hiển thị, không phải chẩn đoán.';

  static const aiOffNote = 'Bạn có thể tắt phản hồi AI trong Hồ sơ bất cứ '
      'lúc nào. Khi tắt, nhật ký không được gửi tới AI. Tài khoản từng chọn '
      '"Chỉ viết nhật ký" sẽ tiếp tục tắt cho đến khi bạn tự bật lại.';

  static const choiceNote =
      'Bạn vẫn có thể viết và lưu nhật ký khi không dùng phản hồi AI.';
}
