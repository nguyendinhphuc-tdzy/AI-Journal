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
  /// 29/10/2026) and can be turned off in Hồ sơ. Version 2: AI is no longer
  /// a choice on this screen.
  static const localOllama = DataPolicy(
    approved: false,
    version: 'local-ollama-demo-2',
    realLocalAi: true,
    storage: AppConfig.journalCloudEnabled
        ? 'Nhật ký được lưu trong tài khoản của bạn trên máy chủ của nhóm, '
            'để bạn mở lại khi đăng nhập.'
        : 'Nhật ký được lưu trên thiết bị này, riêng cho tài khoản của bạn.',
    aiRequest: 'Khi bạn lưu nhật ký hoặc bấm Nhìn lại cùng bạn, nội dung được '
        'gửi qua máy chủ của nhóm tới AI (mô hình Ollama chạy trên máy tính '
        'của nhóm) để phân tích và đặt câu hỏi. Việc này không diễn ra trên '
        'điện thoại và cần phiên đăng nhập hợp lệ.',
    policyUrl: null,
    choice: aiOffNote,
  );

  static const aiOffNote = 'Bạn có thể tắt phản hồi AI trong Hồ sơ bất cứ '
      'lúc nào. Khi tắt, nhật ký không được gửi tới AI.';

  static const choiceNote =
      'Bạn vẫn có thể viết và lưu nhật ký khi không dùng phản hồi AI.';
}
