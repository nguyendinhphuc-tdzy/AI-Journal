"""Deterministic emotion mapping in step with Flutter emotion_scale.dart.

These are UI display bands, NOT psychological or diagnostic scores.
Unknown emotions have no score; do not fabricate a value for the chart.
"""
import re

GROUPS = (
    ("joy", 90, ("vui", "vui vẻ", "hạnh phúc", "hào hứng", "phấn khởi",
                "háo hức", "tự hào", "yêu đời", "thích thú", "phấn chấn",
                "hân hoan", "sung sướng")),
    ("grateful", 85, ("biết ơn", "trân trọng", "cảm kích", "ấm lòng")),
    ("calm", 80, ("bình yên", "nhẹ nhõm", "thư giãn", "thoải mái",
                  "bình an", "an yên", "dịu nhẹ", "thanh thản",
                  "bình tĩnh", "ấm áp", "nhẹ lòng", "thư thái")),
    ("hopeful", 72, ("hy vọng", "hi vọng", "lạc quan", "mong chờ",
                    "quyết tâm", "động lực", "tò mò", "kỳ vọng", "tin tưởng")),
    ("mixed", 55, ("bối rối", "lẫn lộn", "phân vân", "băn khoăn",
                  "hoài niệm", "bâng khuâng", "bình thường", "trung tính",
                  "chưa rõ", "trầm ngâm", "suy tư")),
    ("tired", 40, ("mệt", "mệt mỏi", "kiệt sức", "uể oải", "đuối",
                   "nặng nề", "kiệt quệ", "chán chường")),
    ("anxious", 35, ("lo", "lo lắng", "lo âu", "áp lực", "căng thẳng",
                     "bồn chồn", "bất an", "choáng ngợp", "quá tải",
                     "hồi hộp", "ngợp", "sốt ruột")),
    ("afraid", 30, ("sợ", "sợ hãi", "hoảng", "hoảng sợ", "e ngại", "lo sợ")),
    ("angry", 30, ("tức", "tức giận", "giận", "bực", "bực bội",
                   "khó chịu", "ức chế", "phẫn nộ")),
    ("sad", 25, ("buồn", "thất vọng", "chán", "chán nản", "cô đơn",
                 "tủi thân", "trống rỗng", "đau lòng", "tổn thương",
                 "hụt hẫng", "tiếc nuối", "tự ti", "u sầu", "buồn bã")),
)
NEGATIONS = {"không", "chẳng", "chưa", "hết"}

def classify_emotion(emotion: str) -> tuple[str | None, int | None]:
    # Flutter treats punctuation as separators; preserve Unicode word content.
    words = re.findall(r"[^\W_]+", emotion.casefold(), flags=re.UNICODE)
    text = " " + " ".join(words) + " "
    matches = []
    for group, score, phrases in GROUPS:
        found = False
        for phrase in phrases:
            if f" {phrase} " not in text:
                continue
            if any(f" {negative} {phrase} " in text for negative in NEGATIONS):
                continue
            found = True
            break
        if found:
            matches.append((group, score))
    if not matches:
        return None, None
    if len(matches) == 1:
        return matches[0]
    return "mixed", round(sum(score for _, score in matches) / len(matches))
