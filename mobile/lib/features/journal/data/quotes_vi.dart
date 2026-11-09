/// The team's quotes (Vy, 29/10/2026, "App Mobile (3).pdf"), as written
/// there; only the dashes are left out (the author shows on its own line).
///
/// [Quote.attribution] says how sure the attribution is. [Quote.autoPick]
/// is whether the app may choose it after an analysis: never a quote whose
/// attribution is in doubt, and never one that does not fit a personal
/// journal (politics, society, science) or could read wrong to someone in
/// distress. Change either only after checking the source.
library;

enum Attribution {
  /// The wording traces to a known work, letter, speech or interview.
  known,

  /// Widely shared but not found in the author's own work, or the source
  /// is unclear: to check before it is ever shown.
  doubtful,
}

class Quote {
  const Quote(
    this.id,
    this.text,
    this.author, {
    this.work,
    this.foundAt,
    this.attribution = Attribution.known,
    this.autoPick = true,
    this.tags = const [],
  });

  /// The number in the team's list.
  final int id;
  final String text;
  final String author;

  /// Where the author said or wrote it, when known.
  final String? work;

  /// Where the team found it (as noted in the list).
  final String? foundAt;
  final Attribution attribution;
  final bool autoPick;

  /// What it speaks to: keys of [quoteTopics].
  final List<String> tags;

  bool get pickable => autoPick && attribution == Attribution.known;
}

/// Words that point to each topic, in the user's entry or the AI's analysis.
/// Matched as whole words or phrases, lower case.
const quoteTopics = <String, List<String>>{
  'thời gian': ['thời gian', 'lãng phí', 'trì hoãn', 'bận rộn', 'muộn',
      'deadline', 'hạn chót'],
  'áp lực': ['áp lực', 'căng thẳng', 'quá tải', 'ngợp', 'choáng ngợp',
      'nặng nề', 'stress', 'chồng chất', 'dồn', 'gánh nặng'],
  'mệt mỏi': ['mệt', 'mệt mỏi', 'kiệt sức', 'uể oải', 'đuối', 'kiệt quệ'],
  'buồn': ['buồn', 'chán', 'thất vọng', 'trống rỗng', 'khóc', 'tủi thân',
      'u sầu', 'đau lòng', 'tổn thương'],
  'lo lắng': ['lo', 'lo lắng', 'lo âu', 'bồn chồn', 'bất an', 'hồi hộp',
      'suy nghĩ nhiều'],
  'sợ hãi': ['sợ', 'sợ hãi', 'hoảng', 'e ngại', 'nỗi sợ', 'né tránh',
      'trốn tránh'],
  'cô đơn': ['cô đơn', 'một mình', 'lẻ loi', 'cô độc'],
  // Not "điểm" or "trường" alone: they are in "thời điểm", "môi trường".
  'học tập': ['học', 'việc học', 'học tập', 'bài', 'bài tập', 'thi',
      'kỳ thi', 'điểm số', 'điểm kém', 'điểm thi', 'trường học',
      'đến trường', 'ở trường', 'lớp', 'kiến thức', 'kiểm tra', 'môn'],
  'công việc': ['công việc', 'làm việc', 'sếp', 'dự án', 'nghề',
      'đồng nghiệp', 'việc làm'],
  // Not "thương" alone ("tổn thương"), nor "bạn" ("bạn cảm thấy").
  'tình yêu': ['yêu', 'tình yêu', 'người yêu', 'chia tay', 'crush',
      'yêu thương', 'tình cảm', 'hẹn hò'],
  'tình bạn': ['bạn bè', 'bạn thân', 'tình bạn', 'người bạn'],
  'gia đình': ['gia đình', 'bố', 'mẹ', 'bố mẹ', 'ba mẹ', 'cha mẹ'],
  'bản thân': ['bản thân', 'chính mình', 'tự ti', 'tự tin', 'giá trị',
      'hiểu mình', 'so sánh'],
  'ước mơ': ['ước mơ', 'mục tiêu', 'đam mê', 'tương lai', 'sự nghiệp',
      'định hướng', 'hoài bão'],
  'thất bại': ['thất bại', 'sai lầm', 'vấp ngã', 'trượt', 'rớt', 'hỏng',
      'không đạt'],
  'can đảm': ['can đảm', 'dũng cảm', 'đối mặt', 'vượt qua', 'cố gắng',
      'kiên trì', 'nỗ lực'],
  'hy vọng': ['hy vọng', 'hi vọng', 'lạc quan', 'niềm tin', 'tin tưởng'],
  'vui': ['vui', 'hạnh phúc', 'biết ơn', 'nhẹ nhõm', 'bình yên',
      'thư giãn', 'thoải mái', 'hài lòng', 'bình an'],
  'tha thứ': ['tha thứ', 'giận', 'tức giận', 'tức', 'oán', 'bực'],
  'thiên nhiên': ['thiên nhiên', 'công viên', 'biển', 'núi', 'cây',
      'mưa', 'nắng', 'đi dạo', 'bầu trời', 'hoàng hôn'],
  'cho đi': ['giúp đỡ', 'cho đi', 'tử tế', 'sẻ chia'],
  'nhớ': ['nhớ', 'nhớ nhà', 'xa nhà', 'quê', 'kỷ niệm'],
};

const quotesVi = <Quote>[
  // I. Cuộc sống và giá trị thời gian
  Quote(1, 'Không phải chúng ta có quá ít thời gian, mà là chúng ta đã lãng '
      'phí quá nhiều thời gian.', 'Seneca',
      work: 'Về sự ngắn ngủi của đời người', tags: ['thời gian']),
  Quote(2, 'Thời gian đã mất sẽ không bao giờ tìm lại được.',
      'Benjamin Franklin',
      work: 'Poor Richard\'s Almanack', tags: ['thời gian']),
  Quote(3, 'Cuộc sống giống như việc đi xe đạp. Để giữ thăng bằng, bạn phải '
      'tiếp tục tiến về phía trước.', 'Albert Einstein',
      work: 'Thư gửi con trai Eduard, 1930',
      tags: ['thất bại', 'mệt mỏi', 'can đảm']),
  Quote(4, 'Cuộc đời hoặc là một cuộc phiêu lưu táo bạo, hoặc chẳng là gì cả.',
      'Helen Keller', work: 'The Open Door', tags: ['ước mơ', 'can đảm']),
  Quote(5, 'Thời gian của bạn có hạn, vì vậy đừng lãng phí nó để sống cuộc '
      'đời của người khác.', 'Steve Jobs',
      work: 'Bài phát biểu tại Stanford, 2005', foundAt: 'Stanford Report',
      tags: ['bản thân', 'ước mơ', 'thời gian']),
  Quote(6, 'Chúng ta đều đang sống, đều tìm kiếm hạnh phúc; cuộc đời mỗi '
      'người khác nhau nhưng cũng rất giống nhau.', 'Anne Frank',
      work: 'Nhật ký Anne Frank', tags: ['bản thân', 'vui', 'cô đơn']),
  Quote(7, 'Ý nghĩa cuộc sống không phải là điều có sẵn để khám phá, mà là '
      'điều mỗi người phải tự tạo nên.', 'Antoine de Saint-Exupéry',
      attribution: Attribution.doubtful),
  Quote(8, 'Yêu thương bản thân là khởi đầu của một mối tình kéo dài suốt '
      'cuộc đời.', 'Oscar Wilde',
      work: 'An Ideal Husband', tags: ['bản thân', 'buồn']),
  Quote(9, 'Hãy bắt đầu sống ngay từ bây giờ và xem mỗi ngày như một cuộc đời '
      'trọn vẹn.', 'Seneca',
      work: 'Thư gửi Lucilius', tags: ['thời gian', 'lo lắng']),
  Quote(10, 'Cuộc đời một người có giá trị khi người ấy biết trân trọng cuộc '
      'đời của người khác bằng tình yêu, tình bạn và lòng trắc ẩn.',
      'Simone de Beauvoir',
      work: 'Tuổi già (La Vieillesse)', tags: ['tình bạn', 'cho đi']),

  // II. Nghị lực, lòng can đảm và vượt qua khó khăn
  Quote(11, 'Tôi học được rằng lòng can đảm không phải là không biết sợ, mà '
      'là chiến thắng nỗi sợ hãi.', 'Nelson Mandela',
      work: 'Long Walk to Freedom', tags: ['sợ hãi', 'can đảm', 'lo lắng']),
  Quote(12, 'Không có lòng can đảm, bạn không thể thực hành bất kỳ đức hạnh '
      'nào một cách bền bỉ.', 'Maya Angelou',
      attribution: Attribution.doubtful, tags: ['can đảm']),
  Quote(13, 'Giữa mùa đông lạnh giá, cuối cùng tôi nhận ra bên trong mình có '
      'một mùa hè bất khả chiến bại.', 'Albert Camus',
      work: 'Trở về Tipasa', foundAt: 'Wikiquote',
      tags: ['buồn', 'mệt mỏi', 'hy vọng']),
  Quote(14, 'Bất chấp tất cả, tôi vẫn tin rằng sâu thẳm trong trái tim, con '
      'người thực sự tốt đẹp.', 'Anne Frank',
      work: 'Nhật ký Anne Frank', tags: ['hy vọng', 'tha thứ']),
  Quote(15, 'Mỗi khi người khác cố đe dọa tôi, lòng can đảm trong tôi lại '
      'trỗi dậy.', 'Jane Austen',
      work: 'Kiêu hãnh và định kiến', tags: ['sợ hãi', 'can đảm']),
  Quote(16, 'Đôi khi cuộc đời sẽ ném một viên gạch vào đầu bạn. Đừng đánh mất '
      'niềm tin.', 'Steve Jobs',
      work: 'Bài phát biểu tại Stanford, 2005', tags: ['thất bại', 'hy vọng']),
  Quote(17, 'Không phải mọi điều ta đối mặt đều có thể thay đổi, nhưng không '
      'điều gì có thể thay đổi nếu ta không dám đối mặt.', 'James Baldwin',
      work: 'As Much Truth As One Can Bear, 1962',
      tags: ['sợ hãi', 'can đảm', 'lo lắng']),
  // Kind, but to someone in distress it could read the wrong way.
  Quote(18, 'Đôi khi, chỉ riêng việc tiếp tục sống cũng đã là một hành động '
      'dũng cảm.', 'Seneca',
      work: 'Thư gửi Lucilius', autoPick: false),
  Quote(19, 'Khi tìm được con đường của mình, bạn đừng sợ hãi. Bạn cần đủ can '
      'đảm để mắc sai lầm.', 'Paulo Coelho',
      work: 'Brida', tags: ['thất bại', 'sợ hãi', 'ước mơ']),
  Quote(20, 'Lạc quan là niềm tin dẫn đến thành tựu. Không điều gì có thể hoàn '
      'thành nếu thiếu hy vọng.', 'Helen Keller',
      work: 'Optimism', foundAt: 'Wikiquote', tags: ['hy vọng', 'ước mơ']),

  // III. Tri thức, tư duy và học hỏi
  Quote(21, 'Trí tưởng tượng quan trọng hơn kiến thức. Kiến thức có giới hạn, '
      'còn trí tưởng tượng bao trùm thế giới.', 'Albert Einstein',
      work: 'Phỏng vấn trên The Saturday Evening Post, 1929',
      tags: ['học tập']),
  Quote(22, 'Không có gì trong cuộc sống đáng để sợ hãi; mọi thứ chỉ cần được '
      'thấu hiểu.', 'Marie Curie',
      attribution: Attribution.doubtful, tags: ['sợ hãi']),
  Quote(23, 'Nếu tôi nhìn xa hơn những người khác, ấy là vì tôi đứng trên vai '
      'những người khổng lồ.', 'Isaac Newton',
      work: 'Thư gửi Robert Hooke, 1675', tags: ['học tập']),
  Quote(24, 'Biết điều mình biết và biết điều mình không biết, đó mới là tri '
      'thức thực sự.', 'Khổng Tử', work: 'Luận ngữ', tags: ['học tập']),
  Quote(25, 'Học mà không suy nghĩ thì vô ích; suy nghĩ mà không học hỏi thì '
      'nguy hiểm.', 'Khổng Tử',
      work: 'Luận ngữ', foundAt: 'Wikiquote', tags: ['học tập']),
  Quote(26, 'Nguyên tắc đầu tiên là đừng tự lừa dối mình, bởi chính bạn là '
      'người dễ bị mình đánh lừa nhất.', 'Richard Feynman',
      work: 'Cargo Cult Science, 1974', tags: ['bản thân', 'học tập']),
  Quote(27, 'Chừng nào còn sống, bạn vẫn cần tiếp tục học cách sống.',
      'Seneca', work: 'Thư gửi Lucilius', tags: ['học tập', 'bản thân']),
  Quote(28, 'Giáo dục là vũ khí mạnh mẽ nhất mà chúng ta có thể sử dụng để '
      'thay đổi thế giới.', 'Nelson Mandela', tags: ['học tập']),
  Quote(29, 'Một đứa trẻ, một người thầy, một cây bút và một cuốn sách có thể '
      'thay đổi cả thế giới.', 'Malala Yousafzai',
      work: 'Bài phát biểu tại Liên Hợp Quốc, 2013', foundAt: 'malala.org',
      tags: ['học tập']),
  Quote(30, 'Nếu có một cuốn sách bạn thật sự muốn đọc nhưng chưa ai viết, '
      'chính bạn phải viết nó.', 'Toni Morrison', tags: ['ước mơ']),

  // IV. Ước mơ, thành công và hành động
  Quote(31, 'Hành trình ngàn dặm bắt đầu từ một bước chân.', 'Lão Tử',
      work: 'Đạo Đức Kinh', tags: ['áp lực', 'ước mơ', 'can đảm']),
  Quote(32, 'Cách duy nhất để thực sự hài lòng là làm công việc mà bạn tin '
      'rằng tuyệt vời. Và cách duy nhất để làm việc tuyệt vời là yêu điều '
      'mình làm.', 'Steve Jobs',
      work: 'Bài phát biểu tại Stanford, 2005', tags: ['công việc', 'ước mơ']),
  Quote(33, 'Mọi đứa trẻ đều là nghệ sĩ. Vấn đề là làm sao giữ được tâm hồn '
      'nghệ sĩ khi trưởng thành.', 'Pablo Picasso',
      attribution: Attribution.doubtful),
  Quote(34, 'Sự hoàn hảo đạt được không phải khi không còn gì để thêm vào, mà '
      'khi không còn gì có thể bỏ bớt.', 'Antoine de Saint-Exupéry',
      work: 'Cõi người ta (Terre des hommes)', tags: ['áp lực', 'công việc']),
  Quote(35, 'Khi bạn thực sự khao khát một điều gì đó, cả vũ trụ sẽ hợp sức '
      'giúp bạn đạt được nó.', 'Paulo Coelho',
      work: 'Nhà giả kim', tags: ['ước mơ', 'hy vọng']),
  Quote(36, 'Thật tuyệt vời khi không ai phải chờ đợi, mà có thể bắt đầu ngay '
      'lúc này để góp phần thay đổi thế giới.', 'Anne Frank',
      work: 'Give (Chuyện kể từ căn nhà phía sau)', tags: ['cho đi', 'ước mơ']),
  Quote(37, 'Để thực sự nhìn thấy một điều gì đó cần có thời gian, cũng như để '
      'có một người bạn cần có thời gian.', 'Georgia O\'Keeffe',
      tags: ['tình bạn', 'thời gian']),
  Quote(38, 'Người ta nên luôn giữ cho mình một chút bất ngờ, một chút khác '
      'thường.', 'Oscar Wilde',
      work: 'Phrases and Philosophies for the Use of the Young',
      autoPick: false),
  Quote(39, 'Tôi không tìm kiếm, tôi tìm thấy.', 'Pablo Picasso',
      attribution: Attribution.doubtful),
  Quote(40, 'Nếu bạn vẫn chưa tìm thấy điều mình yêu thích, hãy tiếp tục tìm '
      'kiếm. Đừng vội bằng lòng.', 'Steve Jobs',
      work: 'Bài phát biểu tại Stanford, 2005', foundAt: 'Stanford Report',
      tags: ['ước mơ', 'công việc']),

  // V. Tình yêu và những rung động của trái tim
  Quote(41, 'Người ta chỉ nhìn thấy rõ bằng trái tim. Những điều cốt yếu thì '
      'mắt thường không thể thấy được.', 'Antoine de Saint-Exupéry',
      work: 'Hoàng tử bé', tags: ['tình yêu', 'tình bạn']),
  Quote(42, 'Được yêu hoặc từng yêu, thế là đủ. Đừng đòi hỏi thêm gì nữa.',
      'Victor Hugo', work: 'Những người khốn khổ', tags: ['tình yêu']),
  Quote(43, 'Tình yêu không phải là nhìn nhau, mà là cùng nhau nhìn về một '
      'hướng.', 'Antoine de Saint-Exupéry',
      work: 'Cõi người ta (Terre des hommes)', tags: ['tình yêu']),
  Quote(44, 'Tình yêu không bắt đầu và kết thúc theo cách chúng ta thường '
      'nghĩ. Tình yêu là một cuộc đấu tranh, một hành trình trưởng thành.',
      'James Baldwin', work: 'Nobody Knows My Name', tags: ['tình yêu']),
  Quote(45, 'Khi yêu, chúng ta luôn cố gắng trở thành phiên bản tốt đẹp hơn '
      'của chính mình.', 'Paulo Coelho',
      work: 'Nhà giả kim', tags: ['tình yêu', 'bản thân']),
  Quote(46, 'Tình yêu tốt đẹp hơn lòng thù hận, vì tình yêu tạo nên sự hòa hợp '
      'thay vì xung đột.', 'Bertrand Russell',
      attribution: Attribution.doubtful, tags: ['tha thứ']),
  Quote(47, 'Yêu, là chết ở trong lòng một ít.', 'Xuân Diệu',
      work: 'Bài thơ Yêu', tags: ['tình yêu', 'buồn']),
  Quote(48, 'Nếu tôi có thể ngăn một trái tim tan vỡ, cuộc đời tôi sẽ không vô '
      'ích.', 'Emily Dickinson', tags: ['cho đi']),
  Quote(49, 'Không ai thực sự mất đi một người, bởi không ai có thể sở hữu một '
      'người khác.', 'Paulo Coelho',
      attribution: Attribution.doubtful, tags: ['tình yêu']),
  Quote(50, 'Một người hạnh phúc cũng sẽ khiến những người khác hạnh phúc.',
      'Anne Frank', attribution: Attribution.doubtful, tags: ['vui']),

  // VI. Tình bạn, lòng nhân ái và cách đối nhân xử thế
  Quote(51, 'Tôi thà bước đi cùng một người bạn trong bóng tối còn hơn đi một '
      'mình giữa ánh sáng.', 'Helen Keller',
      attribution: Attribution.doubtful, tags: ['tình bạn']),
  Quote(52, 'Một mình, chúng ta làm được rất ít; cùng nhau, chúng ta có thể làm '
      'được rất nhiều.', 'Helen Keller',
      attribution: Attribution.doubtful, tags: ['tình bạn']),
  Quote(53, 'Hãy trân trọng và tận hưởng tình bạn, bởi chúng ta không biết '
      'mình còn được hưởng đặc ân ấy bao lâu.', 'Seneca',
      work: 'Thư gửi Lucilius', tags: ['tình bạn']),
  Quote(54, 'Bạn bè chính là tài sản của tôi.', 'Emily Dickinson',
      work: 'Thư, 1858', tags: ['tình bạn']),
  Quote(55, 'Hãy nuôi dưỡng đủ lòng can đảm để đứng lên bảo vệ chính mình, rồi '
      'đứng lên bảo vệ người khác.', 'Maya Angelou',
      attribution: Attribution.doubtful, tags: ['can đảm']),
  Quote(56, 'Thiện căn ở tại lòng ta.', 'Nguyễn Du',
      work: 'Truyện Kiều', tags: ['bản thân', 'cho đi']),
  Quote(57, 'Chưa ai trở nên nghèo khó vì biết cho đi.', 'Anne Frank',
      work: 'Give (Chuyện kể từ căn nhà phía sau)', tags: ['cho đi']),
  Quote(58, 'Làm người, trước hết chính là biết chịu trách nhiệm.',
      'Antoine de Saint-Exupéry',
      work: 'Cõi người ta (Terre des hommes)', tags: ['bản thân', 'công việc']),
  Quote(59, 'Cuộc sống tốt đẹp là cuộc sống được truyền cảm hứng bởi tình yêu '
      'và được dẫn dắt bởi tri thức.', 'Bertrand Russell',
      work: 'What I Believe', tags: ['học tập', 'tình yêu']),
  Quote(60, 'Người yếu đuối không bao giờ biết tha thứ. Tha thứ là phẩm chất '
      'của người mạnh mẽ.', 'Mahatma Gandhi',
      work: 'Young India', foundAt: 'Wikiquote', tags: ['tha thứ']),

  // VII. Hạnh phúc, tự do và thái độ sống
  Quote(61, 'Điều khiến con người phiền muộn không phải bản thân sự việc, mà '
      'là cách họ nhìn nhận sự việc ấy.', 'Epictetus',
      work: 'Enchiridion', tags: ['lo lắng', 'áp lực', 'buồn']),
  Quote(62, 'Có một vẻ đẹp kỳ diệu trong những nhịp điệu lặp lại của thiên '
      'nhiên: bình minh đến sau màn đêm, mùa xuân đến sau mùa đông.',
      'Rachel Carson',
      work: 'The Sense of Wonder', tags: ['thiên nhiên', 'hy vọng', 'buồn']),
  Quote(63, 'Hãy nghĩ về tất cả những điều đẹp đẽ vẫn còn quanh bạn và cảm '
      'thấy hạnh phúc.', 'Anne Frank',
      work: 'Nhật ký Anne Frank', tags: ['buồn', 'vui', 'thiên nhiên']),
  Quote(64, 'Thật dại dột khi bất hạnh ngay hôm nay chỉ vì lo sợ rằng một ngày '
      'nào đó mình có thể bất hạnh.', 'Seneca',
      work: 'Thư gửi Lucilius', tags: ['lo lắng', 'sợ hãi']),
  Quote(65, 'Đến một lúc nào đó trong đời, vẻ đẹp của thế giới tự nó đã là '
      'đủ. Bạn không cần phải chụp ảnh, vẽ lại hay thậm chí ghi nhớ nó.',
      'Toni Morrison', work: 'Tar Baby', tags: ['thiên nhiên', 'vui']),
  Quote(66, 'Đừng chờ đợi ngày phán xét cuối cùng. Nó diễn ra mỗi ngày.',
      'Albert Camus', work: 'Sa ngã (La Chute)', autoPick: false),
  Quote(67, 'Cuộc đời tôi chính là thông điệp của tôi.', 'Mahatma Gandhi',
      autoPick: false),
  Quote(68, 'Người ta không sinh ra đã là phụ nữ; người ta trở thành phụ nữ.',
      'Simone de Beauvoir', work: 'Giới tính thứ hai', autoPick: false),
  Quote(69, 'Không có gì quý hơn độc lập, tự do.', 'Hồ Chí Minh',
      work: 'Lời kêu gọi ngày 17/7/1966',
      foundAt: 'Học viện Cảnh sát nhân dân', autoPick: false),
  Quote(70, 'Chỉ những người hời hợt mới hiểu rõ chính mình.', 'Oscar Wilde',
      work: 'Phrases and Philosophies for the Use of the Young',
      autoPick: false),

  // VIII. Xã hội, thiên nhiên, nghệ thuật và chiều sâu tư tưởng
  Quote(71, 'Một quốc gia không nên được đánh giá qua cách đối xử với những '
      'người có địa vị cao nhất, mà qua cách đối xử với những người ở tầng '
      'lớp thấp nhất.', 'Nelson Mandela',
      work: 'Long Walk to Freedom', autoPick: false),
  Quote(72, 'Chúng ta phải học cách sống cùng nhau như anh em, nếu không sẽ '
      'cùng diệt vong như những kẻ khờ dại.', 'Martin Luther King Jr.',
      work: 'Bài phát biểu, 1964', autoPick: false),
  Quote(73, 'Chúng ta không thể cùng thành công khi một nửa trong số chúng ta '
      'vẫn bị kìm hãm.', 'Malala Yousafzai',
      work: 'Bài phát biểu tại Liên Hợp Quốc, 2013', autoPick: false),
  Quote(74, 'Mỗi người đều phải được tôn trọng như một cá thể, nhưng không ai '
      'nên bị thần tượng hóa.', 'Albert Einstein',
      work: 'Thế giới như tôi thấy', autoPick: false),
  Quote(75, 'Mục đích của khoa học là khám phá và soi sáng sự thật. Và theo '
      'tôi, đó cũng là mục đích của văn chương.', 'Rachel Carson',
      work: 'Phát biểu nhận National Book Award, 1952', autoPick: false),
  Quote(76, 'Một nhà khoa học trong phòng thí nghiệm không chỉ là một kỹ thuật '
      'viên, mà còn là một đứa trẻ đứng trước những hiện tượng thiên nhiên kỳ '
      'diệu.', 'Marie Curie', autoPick: false),
  Quote(77, 'Nếu muốn làm một chiếc bánh táo hoàn toàn từ đầu, trước tiên bạn '
      'phải tạo ra cả vũ trụ.', 'Carl Sagan',
      work: 'Cosmos', autoPick: false),
  Quote(78, 'Khoa học là niềm tin rằng ngay cả các chuyên gia cũng có thể thiếu '
      'hiểu biết.', 'Richard Feynman',
      work: 'What is Science?, 1966', autoPick: false),
  Quote(79, 'Khi ta ở, chỉ là nơi đất ở. Khi ta đi, đất đã hóa tâm hồn.',
      'Chế Lan Viên',
      work: 'Tiếng hát con tàu', foundAt: 'Znews.vn', tags: ['nhớ']),
  Quote(80, 'Chúng ta biết mình là ai, nhưng không biết mình có thể trở thành '
      'ai.', 'William Shakespeare',
      work: 'Hamlet', tags: ['bản thân', 'ước mơ', 'lo lắng']),
];
