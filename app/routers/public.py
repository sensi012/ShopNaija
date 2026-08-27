"""Public routes: homepage, product listing, product detail, search."""
from fastapi import APIRouter, Request, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from sqlalchemy import or_

from database import get_db
import models
from security import get_current_user, get_cart_count
from config import settings

router = APIRouter()


def ctx(request: Request, db: Session, **extra):
    """Build common template context."""
    user = get_current_user(request, db)
    return {
        "request": request,
        "current_user": user,
        "cart_count": get_cart_count(user, db),
        "settings": settings,
        **extra,
    }


@router.get("/", response_class=HTMLResponse)
def homepage(request: Request, db: Session = Depends(get_db)):
    categories = db.query(models.Category).all()
    featured = (
        db.query(models.Product)
        .filter(models.Product.featured == True, models.Product.stock > 0)
        .order_by(models.Product.created_at.desc())
        .limit(8)
        .all()
    )
    return request.state.templates.TemplateResponse(
        "index.html",
        ctx(request, db, categories=categories, featured=featured),
    )


@router.get("/products", response_class=HTMLResponse)
def product_list(
    request: Request,
    db: Session = Depends(get_db),
    q: str = "",
    category: str = "",
    min_price: str = "",
    max_price: str = "",
    sort: str = "newest",
    page: int = 1,
):
    per_page = 12
    query = db.query(models.Product).filter(models.Product.stock > 0)

    if q:
        query = query.filter(
            or_(
                models.Product.name.ilike(f"%{q}%"),
                models.Product.description.ilike(f"%{q}%"),
            )
        )
    if category:
        query = query.join(models.Category).filter(models.Category.slug == category)
    if min_price:
        try:
            query = query.filter(models.Product.price >= float(min_price))
        except ValueError:
            pass
    if max_price:
        try:
            query = query.filter(models.Product.price <= float(max_price))
        except ValueError:
            pass

    if sort == "price_asc":
        query = query.order_by(models.Product.price.asc())
    elif sort == "price_desc":
        query = query.order_by(models.Product.price.desc())
    else:
        query = query.order_by(models.Product.created_at.desc())

    total = query.count()
    products = query.offset((page - 1) * per_page).limit(per_page).all()
    total_pages = (total + per_page - 1) // per_page

    categories = db.query(models.Category).all()
    return request.state.templates.TemplateResponse(
        "products.html",
        ctx(
            request,
            db,
            products=products,
            categories=categories,
            q=q,
            selected_category=category,
            min_price=min_price,
            max_price=max_price,
            sort=sort,
            page=page,
            total_pages=total_pages,
            total=total,
        ),
    )


@router.get("/products/{slug}", response_class=HTMLResponse)
def product_detail(slug: str, request: Request, db: Session = Depends(get_db)):
    product = db.query(models.Product).filter(models.Product.slug == slug).first()
    if not product:
        return request.state.templates.TemplateResponse(
            "404.html", ctx(request, db), status_code=404
        )
    related = (
        db.query(models.Product)
        .filter(
            models.Product.category_id == product.category_id,
            models.Product.id != product.id,
            models.Product.stock > 0,
        )
        .limit(4)
        .all()
    )
    return request.state.templates.TemplateResponse(
        "product_detail.html",
        ctx(request, db, product=product, related=related),
    )


@router.get("/health")
def health():
    return {"status": "ok", "service": "shopnaija"}
