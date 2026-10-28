from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.modules.community.router import router as community_router
from app.modules.shares.router import router as shares_router
from app.modules.friends.router import router as friends_router
from app.modules.ai.router import router as ai_router
from app.modules.albums.photos_router import router as memory_photos_router
from app.modules.albums.router import router as albums_router
from app.modules.journal.router import router as journal_router
from app.modules.places.router import router as places_router
from app.modules.places.notes_router import router as notes_router
from app.modules.places.links_router import journal_links_router, place_links_router
from app.modules.geo.router import router as geo_router
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
app.include_router(places_router, prefix="/api/v1")
app.include_router(notes_router, prefix="/api/v1")
app.include_router(journal_links_router, prefix="/api/v1")
app.include_router(place_links_router, prefix="/api/v1")
app.include_router(geo_router, prefix="/api/v1")
app.include_router(ai_router, prefix="/api/v1")
app.include_router(albums_router, prefix="/api/v1")
app.include_router(memory_photos_router, prefix="/api/v1")
app.include_router(friends_router, prefix="/api/v1")
app.include_router(shares_router, prefix="/api/v1")
