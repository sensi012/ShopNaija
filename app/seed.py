"""Seed the database with initial categories and sample products."""
import sys
import os

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

sys.path.insert(0, os.path.dirname(__file__))

from database import engine, SessionLocal, Base
import models
from security import hash_password

CATEGORIES = [
    {"name": "Fashion & Clothing", "slug": "fashion", "icon": "👗"},
    {"name": "Electronics", "slug": "electronics", "icon": "📱"},
    {"name": "Food & Groceries", "slug": "food", "icon": "🍎"},
    {"name": "Beauty & Health", "slug": "beauty", "icon": "💄"},
    {"name": "Home & Living", "slug": "home", "icon": "🏠"},
    {"name": "Sports & Fitness", "slug": "sports", "icon": "⚽"},
    {"name": "Books & Stationery", "slug": "books", "icon": "📚"},
    {"name": "Phones & Tablets", "slug": "phones", "icon": "📲"},
]

PRODUCTS = [
    {
        "name": "Ankara Print Wrap Dress",
        "slug": "ankara-print-wrap-dress",
        "description": "Beautiful vibrant Ankara print wrap dress made from premium Nigerian cotton. Perfect for occasions and everyday wear.",
        "price": 15000,
        "stock": 25,
        "category_slug": "fashion",
        "featured": True,
        "image_key": "uploads/products/ankara-print-wrap-dress.jpg",
    },
    {
        "name": "Traditional Agbada Set",
        "slug": "traditional-agbada-set",
        "description": "Complete 3-piece Agbada set including robe, inner shirt, and trouser. Made from high-quality fabric.",
        "price": 45000,
        "stock": 10,
        "category_slug": "fashion",
        "featured": True,
        "image_key": "uploads/products/traditional-agbada-set.jpg",
    },
    {
        "name": "Wireless Bluetooth Earbuds",
        "slug": "wireless-bluetooth-earbuds",
        "description": "True wireless stereo earbuds with 24hr battery life, noise cancellation, and water resistance.",
        "price": 12000,
        "stock": 50,
        "category_slug": "electronics",
        "featured": True,
        "image_key": "uploads/products/wireless-bluetooth-earbuds.jpg",
    },
    {
        "name": "Smartphone Power Bank 20000mAh",
        "slug": "power-bank-20000mah",
        "description": "High-capacity 20000mAh power bank with dual USB output and fast charging support.",
        "price": 8500,
        "stock": 40,
        "category_slug": "phones",
        "featured": False,
        "image_key": "uploads/products/power-bank-20000mah.jpg",
    },
    {
        "name": "Nigerian Jollof Rice Mix",
        "slug": "nigerian-jollof-rice-mix",
        "description": "Authentic Nigerian Jollof rice spice mix. Just add to your pot for that perfect smoky jollof taste.",
        "price": 2500,
        "stock": 100,
        "category_slug": "food",
        "featured": True,
        "image_key": "uploads/products/nigerian-jollof-rice-mix.jpg",
    },
    {
        "name": "Egusi Soup Paste",
        "slug": "egusi-soup-paste",
        "description": "Ready-to-cook ground egusi (melon seed) paste, seasoned with palm oil and spices. 500g pack.",
        "price": 3200,
        "stock": 80,
        "category_slug": "food",
        "featured": False,
        "image_key": "uploads/products/egusi-soup-paste.jpg",
    },
    {
        "name": "Shea Butter Face Cream",
        "slug": "shea-butter-face-cream",
        "description": "100% natural Nigerian shea butter enriched with vitamin E. Deeply moisturises and brightens skin.",
        "price": 5000,
        "stock": 60,
        "category_slug": "beauty",
        "featured": True,
        "image_key": "uploads/products/shea-butter-face-cream.jpg",
    },
    {
        "name": "Black Soap Bar",
        "slug": "black-soap-bar",
        "description": "Traditional African black soap made with plantain ash, palm kernel oil, and cocoa pod.",
        "price": 1500,
        "stock": 150,
        "category_slug": "beauty",
        "featured": False,
        "image_key": "uploads/products/black-soap-bar.jpg",
    },
    {
        "name": "LED Desk Lamp",
        "slug": "led-desk-lamp",
        "description": "Adjustable LED desk lamp with 3 brightness levels, USB charging port, and eye-protection mode.",
        "price": 8000,
        "stock": 35,
        "category_slug": "home",
        "featured": False,
        "image_key": "uploads/products/led-desk-lamp.jpg",
    },
    {
        "name": "Adire Print Throw Pillow (2-Pack)",
        "slug": "adire-print-throw-pillow",
        "description": "Handcrafted Adire (tie-dye) fabric throw pillows. Each pair uniquely patterned.",
        "price": 6500,
        "stock": 20,
        "category_slug": "home",
        "featured": True,
        "image_key": "uploads/products/adire-print-throw-pillow.jpg",
    },
]

def seed():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # Clear existing data for fresh seed
        db.query(models.OrderItem).delete()
        db.query(models.Order).delete()
        db.query(models.CartItem).delete()
        db.query(models.Product).delete()
        db.query(models.Category).delete()
        db.commit()

        # Seed categories
        category_map = {}
        for cat_data in CATEGORIES:
            cat = models.Category(**cat_data)
            db.add(cat)
            db.flush()
            category_map[cat_data["slug"]] = cat.id
            print(f"  [+] Category: {cat_data['name']}")

        # Seed products
        for prod_data in PRODUCTS:
            cat_slug = prod_data.pop("category_slug")
            prod = models.Product(**prod_data, category_id=category_map.get(cat_slug))
            db.add(prod)
            print(f"  [+] Product: {prod_data['name']}")

        # Create admin user
        admin = db.query(models.User).filter_by(email="admin@shopnaija.com").first()
        if not admin:
            admin = models.User(
                email="admin@shopnaija.com",
                password_hash=hash_password("Admin@1234"),
                full_name="Shop Naija Admin",
                is_admin=True,
            )
            db.add(admin)
            print("  [+] Admin user: admin@shopnaija.com / Admin@1234")

        db.commit()
        print("\n Database seeded successfully!")
    except Exception as exc:
        db.rollback()
        print(f" Seed failed: {exc}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    print("Seeding ShopNaija database...")
    seed()
