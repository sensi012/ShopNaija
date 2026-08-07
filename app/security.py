"""JWT + bcrypt security utilities."""
from datetime import datetime, timedelta
from typing import Optional

from jose import jwt, JWTError
from passlib.context import CryptContext
from fastapi import Request
from sqlalchemy.orm import Session

from config import settings
from database import get_db
import models

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(user_id: int) -> str:
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": str(user_id), "exp": expire}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> Optional[int]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id = int(payload.get("sub"))
        return user_id
    except (JWTError, TypeError, ValueError):
        return None


def get_current_user(request: Request, db: Session) -> Optional[models.User]:
    """Read JWT from cookie and return the User, or None if not logged in."""
    token = request.cookies.get("session")
    if not token:
        return None
    user_id = decode_token(token)
    if not user_id:
        return None
    return db.query(models.User).filter(models.User.id == user_id).first()


def get_cart_count(user: Optional[models.User], db: Session) -> int:
    if not user:
        return 0
    from sqlalchemy import func
    result = (
        db.query(func.sum(models.CartItem.quantity))
        .filter(models.CartItem.user_id == user.id)
        .scalar()
    )
    return result or 0
