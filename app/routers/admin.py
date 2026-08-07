"""Admin routes: product CRUD, category management, image uploads."""
import uuid
import os
from fastapi import APIRouter, Request, Depends, Form, UploadFile, File
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session

from database import get_db
import models
from security import get_current_user, get_cart_count
from config import settings

router = APIRouter(prefix="/admin")


def require_admin(request: Request, db: Session):
    user = get_current_user(request, db)
    if not user:
        return None, RedirectResponse("/login?next=/admin", status_code=302)
    if not user.is_admin:
        return None, RedirectResponse("/", status_code=302)
    return user, None


def ctx(request: Request, db: Session, **extra):
    user = get_current_user(request, db)
    return {
        "request": request,
        "current_user": user,
        "cart_count": get_cart_count(user, db),
        "settings": settings,
        **extra,
    }


def upload_to_s3(file: UploadFile) -> str:
    """Upload a file to S3 and return the object key."""
    if not settings.S3_BUCKET:
        return ""
    import boto3
    s3 = boto3.client("s3", region_name=settings.AWS_REGION)
    ext = os.path.splitext(file.filename)[1].lower() or ".jpg"
    key = f"uploads/{uuid.uuid4().hex}{ext}"
    s3.upload_fileobj(
        file.file,
        settings.S3_BUCKET,
        key,
        ExtraArgs={"ContentType": file.content_type or "image/jpeg"},
    )
    return key


# ── Dashboard ────────────────────────────────────────────────────────────────

@router.get("", response_class=HTMLResponse)
@router.get("/", response_class=HTMLResponse)
def admin_dashboard(request: Request, db: Session = Depends(get_db)):
    user, redirect = require_admin(request, db)
    if redirect:
        return redirect

    products = db.query(models.Product).order_by(models.Product.created_at.desc()).all()
    categories = db.query(models.Category).all()
    orders = db.query(models.Order).order_by(models.Order.created_at.desc()).limit(10).all()
    total_users = db.query(models.User).count()
    total_orders = db.query(models.Order).count()
    revenue = sum(o.total for o in db.query(models.Order).all())

    return request.state.templates.TemplateResponse(
        "admin/dashboard.html",
        ctx(
            request, db,
            products=products, categories=categories, orders=orders,
            total_users=total_users, total_orders=total_orders, revenue=revenue,
        ),
    )


# ── Product Add ───────────────────────────────────────────────────────────────

@router.get("/products/new", response_class=HTMLResponse)
def new_product_page(request: Request, db: Session = Depends(get_db)):
    user, redirect = require_admin(request, db)
    if redirect:
        return redirect
    categories = db.query(models.Category).all()
    return request.state.templates.TemplateResponse(
        "admin/product_form.html",
        ctx(request, db, product=None, categories=categories),
    )


@router.post("/products/new")
async def create_product(
    request: Request,
    db: Session = Depends(get_db),
    name: str = Form(...),
    description: str = Form(""),
    price: float = Form(...),
    stock: int = Form(0),
    category_id: int = Form(None),
    featured: bool = Form(False),
    image: UploadFile = File(None),
):
    user, redirect = require_admin(request, db)
    if redirect:
        return redirect

    slug = name.lower().replace(" ", "-").replace("'", "")[:200]
    # ensure uniqueness
    base_slug = slug
    counter = 1
    while db.query(models.Product).filter_by(slug=slug).first():
        slug = f"{base_slug}-{counter}"
        counter += 1

    image_key = ""
    if image and image.filename:
        image_key = upload_to_s3(image)

    product = models.Product(
        name=name, slug=slug, description=description,
        price=price, stock=stock, category_id=category_id,
        featured=featured, image_key=image_key,
    )
    db.add(product)
    db.commit()
    return RedirectResponse("/admin?msg=Product+created", status_code=302)


# ── Product Edit ──────────────────────────────────────────────────────────────

@router.get("/products/{product_id}/edit", response_class=HTMLResponse)
def edit_product_page(product_id: int, request: Request, db: Session = Depends(get_db)):
    user, redirect = require_admin(request, db)
    if redirect:
        return redirect
    product = db.query(models.Product).filter_by(id=product_id).first()
    categories = db.query(models.Category).all()
    return request.state.templates.TemplateResponse(
        "admin/product_form.html",
        ctx(request, db, product=product, categories=categories),
    )


@router.post("/products/{product_id}/edit")
async def update_product(
    product_id: int,
    request: Request,
    db: Session = Depends(get_db),
    name: str = Form(...),
    description: str = Form(""),
    price: float = Form(...),
    stock: int = Form(0),
    category_id: int = Form(None),
    featured: bool = Form(False),
    image: UploadFile = File(None),
):
    user, redirect = require_admin(request, db)
    if redirect:
        return redirect

    product = db.query(models.Product).filter_by(id=product_id).first()
    if not product:
        return RedirectResponse("/admin", status_code=302)

    product.name = name
    product.description = description
    product.price = price
    product.stock = stock
    product.category_id = category_id
    product.featured = featured

    if image and image.filename:
        product.image_key = upload_to_s3(image)

    db.commit()
    return RedirectResponse("/admin?msg=Product+updated", status_code=302)


# ── Product Delete ────────────────────────────────────────────────────────────

@router.post("/products/{product_id}/delete")
def delete_product(product_id: int, request: Request, db: Session = Depends(get_db)):
    user, redirect = require_admin(request, db)
    if redirect:
        return redirect
    product = db.query(models.Product).filter_by(id=product_id).first()
    if product:
        db.delete(product)
        db.commit()
    return RedirectResponse("/admin?msg=Product+deleted", status_code=302)


# ── Category Management ───────────────────────────────────────────────────────

@router.post("/categories/new")
def create_category(
    request: Request,
    db: Session = Depends(get_db),
    name: str = Form(...),
    icon: str = Form("📦"),
):
    user, redirect = require_admin(request, db)
    if redirect:
        return redirect
    slug = name.lower().replace(" ", "-").replace("&", "and")[:100]
    if not db.query(models.Category).filter_by(slug=slug).first():
        db.add(models.Category(name=name, slug=slug, icon=icon))
        db.commit()
    return RedirectResponse("/admin?msg=Category+created", status_code=302)
