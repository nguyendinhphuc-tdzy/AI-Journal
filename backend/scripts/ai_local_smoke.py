"""Run real local Ollama inference with a synthetic Vietnamese diary entry."""
import argparse
import json
import sys

from app.modules.ai.service import OllamaAIProvider


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="qwen3.5:4b")
    args = parser.parse_args()
    provider = OllamaAIProvider("http://127.0.0.1:11434", model=args.model)
    entry = (
        "Câu hỏi: Hôm nay có điều gì đáng nhớ?\n"
        "Trả lời: Tôi hoàn thành một việc nhỏ và đi dạo quanh hồ.\n"
        "Câu hỏi: Khoảnh khắc nào làm tôi muốn dừng lại?\n"
        "Trả lời: Khi nghe tiếng chim và thấy mình bớt vội."
    )
    question = provider.go_deeper(entry)
    reflection = provider.reflect(entry, mood="bình yên")
    if not question.strip() or not all(
        getattr(reflection, field).strip()
        for field in ("emotion", "observation", "reflection", "question")
    ):
        raise RuntimeError("Ollama returned an incomplete reflection")
    print(json.dumps({
        "model": args.model,
        "go_deeper": question,
        "reflection": reflection.model_dump(),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
