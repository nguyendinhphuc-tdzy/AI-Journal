from fastapi import APIRouter

router = APIRouter(prefix="/prompts", tags=["prompts"])


@router.get("/daily")
def get_daily_prompt() -> dict[str, str]:
    return {
        "id": "daily-001",
        "text": "What is something you want to remember about today?",
    }
