from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.modules.ai.router import router as ai_router
from app.modules.journal.router import router as journal_router
from app.modules.profile.router import router as profile_router
from app.modules.streak.router import router as streak_router
from app.modules.prompts.router import router as prompts_router


app = FastAPI(title="AI Diary Backend", version="0.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "ai-diary-backend"}


app.include_router(prompts_router, prefix="/api/v1")
app.include_router(journal_router, prefix="/api/v1")
app.include_router(profile_router, prefix="/api/v1")
app.include_router(streak_router, prefix="/api/v1")
app.include_router(ai_router, prefix="/api/v1")
