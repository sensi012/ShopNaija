"""Auth routes: register, login, logout."""
from fastapi import APIRouter, Request, Depends, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session

from database import get_db
import models
from security import (
    hash_password, verify_password,
    create_access_token, get_current_user, get_cart_count,
)

router = APIRouter()


def ctx(request: Request, db: Session, **extra):
    user = get_current_user(request, db)
    return {
        "request": request,
        "current_user": user,
        "cart_count": get_cart_count(user, db),
        **extra,
    }


@router.get("/register", response_class=HTMLResponse)
def register_page(request: Request, db: Session = Depends(get_db)):
    if get_current_user(request, db):
        return RedirectResponse("/", status_code=302)
    return request.state.templates.TemplateResponse("auth/register.html", ctx(request, db))


@router.post("/register")
def register(
    request: Request,
    db: Session = Depends(get_db),
    full_name: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    confirm_password: str = Form(...),
):
    errors = []
    if len(password) < 6:
        errors.append("Password must be at least 6 characters.")
    if password != confirm_password:
        errors.append("Passwords do not match.")
    if db.query(models.User).filter_by(email=email).first():
        errors.append("An account with this email already exists.")

    if errors:
        return request.state.templates.TemplateResponse(
            "auth/register.html",
            ctx(request, db, errors=errors, full_name=full_name, email=email),
            status_code=422,
        )

    user = models.User(
        email=email,
        full_name=full_name,
        password_hash=hash_password(password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)
    response = RedirectResponse("/?msg=Welcome+to+ShopNaija!", status_code=302)
    response.set_cookie("session", token, httponly=True, max_age=60 * 60 * 24 * 7, samesite="lax")
    return response


@router.get("/login", response_class=HTMLResponse)
def login_page(request: Request, db: Session = Depends(get_db)):
    if get_current_user(request, db):
        return RedirectResponse("/", status_code=302)
    next_url = request.query_params.get("next", "/")
    return request.state.templates.TemplateResponse("auth/login.html", ctx(request, db, next_url=next_url))


@router.post("/login")
def login(
    request: Request,
    db: Session = Depends(get_db),
    email: str = Form(...),
    password: str = Form(...),
    next: str = Form("/"),
):
    user = db.query(models.User).filter_by(email=email).first()
    if not user or not verify_password(password, user.password_hash):
        return request.state.templates.TemplateResponse(
            "auth/login.html",
            ctx(request, db, error="Invalid email or password.", email=email, next_url=next),
            status_code=401,
        )

    token = create_access_token(user.id)
    response = RedirectResponse(next or "/", status_code=302)
    response.set_cookie("session", token, httponly=True, max_age=60 * 60 * 24 * 7, samesite="lax")
    return response


@router.get("/logout")
def logout():
    response = RedirectResponse("/login", status_code=302)
    response.delete_cookie("session")
    return response
