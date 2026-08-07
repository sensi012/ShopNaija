"""ShopNaija FastAPI application entry point."""
import logging
from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

from database import engine, Base
from config import settings

# Create all tables on startup
Base.metadata.create_all(bind=engine)

app = FastAPI(title="ShopNaija", version="1.0.0", docs_url=None, redoc_url=None)

# ── Static Files & Templates ──────────────────────────────────────────────────
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# ── Custom Jinja2 Filters ─────────────────────────────────────────────────────
def naira(value):
    """Format a number as Nigerian Naira."""
    try:
        return f"₦{float(value):,.0f}"
    except (TypeError, ValueError):
        return "₦0"

def image_url(key):
    """Return full image URL from an S3 key."""
    return settings.image_url(key) if key else ""

templates.env.filters["naira"] = naira
templates.env.filters["image_url"] = image_url

# ── Inject templates into request.state for use in routers ───────────────────
@app.middleware("http")
async def inject_templates(request: Request, call_next):
    request.state.templates = templates
    response = await call_next(request)
    return response

# ── Routers ───────────────────────────────────────────────────────────────────
from routers import public, auth, cart, orders, admin  # noqa: E402

app.include_router(public.router)
app.include_router(auth.router)
app.include_router(cart.router)
app.include_router(orders.router)
app.include_router(admin.router)

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
