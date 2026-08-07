"""Cart routes: view, add, update, remove."""
from fastapi import APIRouter, Request, Depends, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from database import get_db
import models
from security import get_current_user, get_cart_count

router = APIRouter()


def require_login(request: Request, db: Session):
    user = get_current_user(request, db)
    if not user:
        return None, RedirectResponse(f"/login?next={request.url.path}", status_code=302)
    return user, None


def ctx(request: Request, db: Session, **extra):
    user = get_current_user(request, db)
    return {
        "request": request,
        "current_user": user,
        "cart_count": get_cart_count(user, db),
        **extra,
    }


@router.get("/cart", response_class=HTMLResponse)
def view_cart(request: Request, db: Session = Depends(get_db)):
    user, redirect = require_login(request, db)
    if redirect:
        return redirect

    items = (
        db.query(models.CartItem)
        .filter(models.CartItem.user_id == user.id)
        .all()
    )
    subtotal = sum(i.product.price * i.quantity for i in items)
    return request.state.templates.TemplateResponse(
        "cart.html",
        ctx(request, db, items=items, subtotal=subtotal),
    )


@router.post("/cart/add")
def add_to_cart(
    request: Request,
    db: Session = Depends(get_db),
    product_id: int = Form(...),
    quantity: int = Form(1),
):
    user, redirect = require_login(request, db)
    if redirect:
        return redirect

    product = db.query(models.Product).filter_by(id=product_id).first()
    if not product or product.stock < 1:
        return RedirectResponse("/products?msg=Product+not+available", status_code=302)

    quantity = max(1, min(quantity, product.stock))
    existing = (
        db.query(models.CartItem)
        .filter_by(user_id=user.id, product_id=product_id)
        .first()
    )
    if existing:
        existing.quantity = min(existing.quantity + quantity, product.stock)
    else:
        db.add(models.CartItem(user_id=user.id, product_id=product_id, quantity=quantity))

    try:
        db.commit()
    except IntegrityError:
        db.rollback()

    return RedirectResponse("/cart", status_code=302)


@router.post("/cart/update")
def update_cart(
    request: Request,
    db: Session = Depends(get_db),
    item_id: int = Form(...),
    quantity: int = Form(...),
):
    user, redirect = require_login(request, db)
    if redirect:
        return redirect

    item = (
        db.query(models.CartItem)
        .filter_by(id=item_id, user_id=user.id)
        .first()
    )
    if item:
        if quantity <= 0:
            db.delete(item)
        else:
            item.quantity = min(quantity, item.product.stock)
        db.commit()

    return RedirectResponse("/cart", status_code=302)


@router.post("/cart/remove")
def remove_from_cart(
    request: Request,
    db: Session = Depends(get_db),
    item_id: int = Form(...),
):
    user, redirect = require_login(request, db)
    if redirect:
        return redirect

    item = (
        db.query(models.CartItem)
        .filter_by(id=item_id, user_id=user.id)
        .first()
    )
    if item:
        db.delete(item)
        db.commit()

    return RedirectResponse("/cart", status_code=302)
