/// OB03: why the user wants to journal. Single choice, optional. Only used
/// to suggest topics and prompts where an editorial mapping exists; never to
/// infer a diagnosis or a personality score. Names are persisted; do not
/// rename.
enum JournalGoal {
  understandMyself('Hiểu bản thân rõ hơn.'),
  recordDailyLife('Ghi lại cuộc sống hằng ngày.'),
  sortThoughts('Sắp xếp những suy nghĩ trong đầu.'),
  seeMyChanges('Nhìn lại sự thay đổi của mình.'),
  other('Một lý do khác.');

  const JournalGoal(this.label);

  final String label;
}
