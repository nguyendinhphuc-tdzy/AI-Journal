from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.database import Base, engine
from app.modules.ai.router import router as ai_router
from app.modules.journal.router import router as journal_router
from app.modules.prompts.router import router as prompts_router

Base.metadata.create_all(bind=engine)

app = FastAPI(title="AI Diary Backend", version="0.1.0")

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
app.include_router(ai_router, prefix="/api/v1")
