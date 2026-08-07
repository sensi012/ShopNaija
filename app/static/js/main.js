/* ShopNaija — Main JS: navbar, dropdowns, mobile menu, filter sidebar */

document.addEventListener('DOMContentLoaded', () => {

  // ── Mobile nav toggle ─────────────────────────────────────────
  const navToggle = document.getElementById('nav-toggle');
  const mobileMenu = document.getElementById('mobile-menu');
  if (navToggle && mobileMenu) {
    navToggle.addEventListener('click', () => {
      const open = mobileMenu.style.display === 'block';
      mobileMenu.style.display = open ? 'none' : 'block';
      navToggle.classList.toggle('active', !open);
    });
  }

  // ── Filter sidebar (mobile) ───────────────────────────────────
  const filterToggle = document.getElementById('filter-toggle');
  const filterSidebar = document.getElementById('filter-sidebar');
  const filterClose   = document.getElementById('filter-close');

  if (filterToggle && filterSidebar) {
    filterToggle.addEventListener('click', () => {
      filterSidebar.classList.toggle('open');
      document.body.style.overflow = filterSidebar.classList.contains('open') ? 'hidden' : '';
    });
  }
  if (filterClose && filterSidebar) {
    filterClose.addEventListener('click', () => {
      filterSidebar.classList.remove('open');
      document.body.style.overflow = '';
    });
  }
  // Close sidebar on backdrop click
  document.addEventListener('click', (e) => {
    if (filterSidebar?.classList.contains('open') &&
        !filterSidebar.contains(e.target) &&
        e.target !== filterToggle) {
      filterSidebar.classList.remove('open');
      document.body.style.overflow = '';
    }
  });

  // ── Dropdown user menu ────────────────────────────────────────
  const dropdown = document.getElementById('user-dropdown');
  if (dropdown) {
    dropdown.addEventListener('mouseenter', () => dropdown.classList.add('open'));
    dropdown.addEventListener('mouseleave', () => dropdown.classList.remove('open'));
    // Also toggle on click for touch devices
    dropdown.querySelector('.dropdown-toggle')?.addEventListener('click', () => {
      dropdown.classList.toggle('open');
    });
  }

  // ── Navbar scroll behaviour ───────────────────────────────────
  const navbar = document.getElementById('navbar');
  if (navbar) {
    let lastScroll = 0;
    window.addEventListener('scroll', () => {
      const current = window.scrollY;
      if (current > 80 && current > lastScroll) {
        navbar.style.transform = 'translateY(-100%)';
      } else {
        navbar.style.transform = 'translateY(0)';
      }
      lastScroll = current;
    }, { passive: true });
    navbar.style.transition = 'transform .3s ease';
  }

  // ── Flash auto-dismiss ────────────────────────────────────────
  document.querySelectorAll('.flash').forEach(el => {
    setTimeout(() => el.remove(), 5000);
  });

  // ── Add-to-cart button animation ─────────────────────────────
  document.querySelectorAll('.btn-add-cart').forEach(btn => {
    btn.closest('form')?.addEventListener('submit', () => {
      btn.textContent = '✓ Added!';
      btn.style.background = '#10B981';
    });
  });

  // ── Cart badge update from localStorage (optimistic UI) ──────
  // After adding to cart, increment the badge count for immediate feedback
  document.querySelectorAll('form[action="/cart/add"]').forEach(form => {
    form.addEventListener('submit', () => {
      const badge = document.getElementById('cart-badge');
      if (badge) {
        const current = parseInt(badge.textContent) || 0;
        badge.textContent = current + 1;
        badge.classList.remove('cart-badge-hidden');
      }
    });
  });

  // ── Image lazy load fallback ──────────────────────────────────
  document.querySelectorAll('img[loading="lazy"]').forEach(img => {
    img.addEventListener('error', () => {
      img.style.display = 'none';
      const placeholder = document.createElement('div');
      placeholder.className = 'product-img-placeholder';
      placeholder.innerHTML = '<span>📦</span>';
      img.parentNode.insertBefore(placeholder, img);
    });
  });

  // ── Search input clear on Escape ──────────────────────────────
  document.getElementById('search-input')?.addEventListener('keydown', e => {
    if (e.key === 'Escape') e.target.value = '';
  });

  // ── Animate product cards on scroll ──────────────────────────
  if ('IntersectionObserver' in window) {
    const cards = document.querySelectorAll('.product-card, .category-card, .why-card');
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.style.opacity = '1';
          entry.target.style.transform = 'translateY(0)';
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.1 });
    cards.forEach(card => {
      card.style.opacity = '0';
      card.style.transform = 'translateY(20px)';
      card.style.transition = 'opacity .4s ease, transform .4s ease';
      observer.observe(card);
    });
  }

});
