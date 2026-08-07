"""Order routes: checkout and order history."""
from fastapi import APIRouter, Request, Depends, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session

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


@router.get("/checkout", response_class=HTMLResponse)
def checkout_page(request: Request, db: Session = Depends(get_db)):
    user, redirect = require_login(request, db)
    if redirect:
        return redirect

    items = db.query(models.CartItem).filter_by(user_id=user.id).all()
    if not items:
        return RedirectResponse("/cart", status_code=302)

    subtotal = sum(i.product.price * i.quantity for i in items)
    shipping = 1500  # flat-rate shipping in Naira
    total = subtotal + shipping

    return request.state.templates.TemplateResponse(
        "checkout.html",
        ctx(request, db, items=items, subtotal=subtotal, shipping=shipping, total=total),
    )


@router.post("/checkout")
def place_order(
    request: Request,
    db: Session = Depends(get_db),
    shipping_name: str = Form(...),
    shipping_address: str = Form(...),
    shipping_city: str = Form(...),
    shipping_state: str = Form(...),
    shipping_phone: str = Form(...),
):
    user, redirect = require_login(request, db)
    if redirect:
        return redirect

    items = db.query(models.CartItem).filter_by(user_id=user.id).all()
    if not items:
        return RedirectResponse("/cart", status_code=302)

    shipping = 1500
    subtotal = sum(i.product.price * i.quantity for i in items)
    total = subtotal + shipping

    order = models.Order(
        user_id=user.id,
        total=total,
        status="pending",
        shipping_name=shipping_name,
        shipping_address=shipping_address,
        shipping_city=shipping_city,
        shipping_state=shipping_state,
        shipping_phone=shipping_phone,
    )
    db.add(order)
    db.flush()

    for item in items:
        db.add(
            models.OrderItem(
                order_id=order.id,
                product_id=item.product_id,
                product_name=item.product.name,
                quantity=item.quantity,
                unit_price=item.product.price,
            )
        )
        # Decrement stock
        item.product.stock = max(0, item.product.stock - item.quantity)
        db.delete(item)

    db.commit()
    return RedirectResponse(f"/orders/{order.id}?success=1", status_code=302)


@router.get("/orders", response_class=HTMLResponse)
def order_history(request: Request, db: Session = Depends(get_db)):
    user, redirect = require_login(request, db)
    if redirect:
        return redirect

    orders = (
        db.query(models.Order)
        .filter_by(user_id=user.id)
        .order_by(models.Order.created_at.desc())
        .all()
    )
    return request.state.templates.TemplateResponse(
        "orders.html", ctx(request, db, orders=orders)
    )


@router.get("/orders/{order_id}", response_class=HTMLResponse)
def order_detail(order_id: int, request: Request, db: Session = Depends(get_db)):
    user, redirect = require_login(request, db)
    if redirect:
        return redirect

    order = db.query(models.Order).filter_by(id=order_id, user_id=user.id).first()
    if not order:
        return RedirectResponse("/orders", status_code=302)

    success = request.query_params.get("success") == "1"
    return request.state.templates.TemplateResponse(
        "order_detail.html", ctx(request, db, order=order, success=success)
    )
