const API_BASE = window.location.origin;

let allProducts = [];
let currentCategory = 'all';
let searchQuery = '';

// Session Management
function getSessionId() {
    let sid = localStorage.getItem('cloudmart_session_id');
    if (!sid) {
        sid = 'cm_' + Math.random().toString(36).substring(2, 9) + Date.now().toString(36);
        localStorage.setItem('cloudmart_session_id', sid);
    }
    document.cookie = `session_id=${sid}; path=/; SameSite=Lax`;
    return sid;
}

const currentSessionId = getSessionId();

function initSessionUI() {
    const display = document.getElementById('session-display');
    if (display) {
        display.textContent = currentSessionId;
    }
}

function getHeaders() {
    return {
        'Content-Type': 'application/json',
        'X-Session-Id': currentSessionId
    };
}

// Toast Notifications
function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;

    let iconSvg = '';
    if (type === 'success') {
        iconSvg = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>`;
    } else if (type === 'error') {
        iconSvg = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ef4444" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>`;
    } else {
        iconSvg = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#38bdf8" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>`;
    }

    toast.innerHTML = `
        ${iconSvg}
        <span class="toast-message">${escapeHtml(message)}</span>
    `;

    container.appendChild(toast);

    setTimeout(() => {
        toast.style.animation = 'toastSlideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) reverse';
        setTimeout(() => toast.remove(), 280);
    }, 3200);
}

// Category Mapping Helper
function categorizeProduct(name) {
    const n = name.toLowerCase();
    if (n.includes('headphone') || n.includes('audio') || n.includes('sound')) return 'audio';
    if (n.includes('keyboard') || n.includes('mouse') || n.includes('webcam')) return 'peripherals';
    if (n.includes('monitor') || n.includes('screen') || n.includes('display')) return 'displays';
    return 'accessories';
}

function getProductIcon(category) {
    switch (category) {
        case 'audio':
            return `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"/></svg>`;
        case 'peripherals':
            return `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="20" height="14" x="2" y="5" rx="2"/><path d="M6 9h.01M10 9h.01M14 9h.01M18 9h.01M8 13h8"/></svg>`;
        case 'displays':
            return `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="20" height="14" x="2" y="3" rx="2"/><path d="M8 21h8M12 17v4"/></svg>`;
        default:
            return `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>`;
    }
}

// Load Products from Product Catalog Service
async function loadProducts() {
    const grid = document.getElementById('products-grid');
    const countLabel = document.getElementById('products-count-label');

    try {
        const res = await fetch(`${API_BASE}/api/products`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        allProducts = await res.json();

        if (countLabel) {
            countLabel.textContent = `${allProducts.length} production items available`;
        }
        renderFilteredProducts();
    } catch (err) {
        grid.innerHTML = `
            <div style="grid-column: 1 / -1; text-align: center; padding: 60px 20px; color: #ef4444;">
                <h3>Unable to reach product-catalog service</h3>
                <p style="color: #94a3b8; margin-top: 8px;">Verify cluster ingress or run <code>docker compose up -d</code> locally.</p>
                <p style="font-size: 0.82rem; margin-top: 6px; font-family: monospace;">Detail: ${escapeHtml(err.message)}</p>
            </div>
        `;
    }
}

function renderFilteredProducts() {
    const grid = document.getElementById('products-grid');

    const filtered = allProducts.filter(p => {
        const cat = categorizeProduct(p.name);
        const matchesCategory = currentCategory === 'all' || cat === currentCategory;
        const matchesSearch = !searchQuery || 
            p.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
            p.description.toLowerCase().includes(searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
    });

    if (filtered.length === 0) {
        grid.innerHTML = `
            <div style="grid-column: 1 / -1; text-align: center; padding: 48px; color: var(--text-muted);">
                <h4>No matching products found</h4>
                <p>Try searching for a different keyword or selecting 'All' categories.</p>
            </div>
        `;
        return;
    }

    grid.innerHTML = filtered.map(p => {
        const category = categorizeProduct(p.name);
        const iconSvg = getProductIcon(category);
        const priceNum = Number(p.price).toFixed(2);

        return `
            <div class="product-card" data-id="${p.id}">
                <div>
                    <div class="card-top">
                        <span class="category-tag">${escapeHtml(category)}</span>
                        <span class="product-id-tag">SKU-${p.id.toString().padStart(3, '0')}</span>
                    </div>
                    <div class="product-icon-wrap">
                        ${iconSvg}
                    </div>
                    <h3 class="product-name">${escapeHtml(p.name)}</h3>
                    <p class="product-desc">${escapeHtml(p.description)}</p>
                </div>

                <div class="card-bottom">
                    <div class="price-box">
                        <span class="price-label">Price</span>
                        <span class="price-value">$${priceNum}</span>
                    </div>
                    <button class="add-cart-btn" onclick="addToCart(${p.id}, '${escapeHtml(p.name)}', ${p.price})">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
                        </svg>
                        <span>Add</span>
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

function handleSearch(val) {
    searchQuery = val.trim();
    renderFilteredProducts();
}

function filterCategory(cat) {
    currentCategory = cat;
    document.querySelectorAll('.tab-btn').forEach(b => {
        b.classList.toggle('active', b.textContent.toLowerCase() === cat || (cat === 'all' && b.textContent === 'All'));
    });
    renderFilteredProducts();
}

// Cart Service Operations
async function addToCart(id, name, price) {
    try {
        const res = await fetch(`${API_BASE}/api/cart/items`, {
            method: 'POST',
            headers: getHeaders(),
            body: JSON.stringify({ product_id: id, name, price: Number(price), quantity: 1 })
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);

        showToast(`Added "${name}" to cart`, 'success');
        await updateCartCount(true);
        if (isDrawerOpen()) {
            await renderCartDrawer();
        }
    } catch (err) {
        showToast('Failed to add item: ' + err.message, 'error');
    }
}

async function updateItemQuantity(productId, delta) {
    try {
        const res = await fetch(`${API_BASE}/api/cart/items`, { headers: getHeaders() });
        if (!res.ok) throw new Error('Failed to fetch cart');
        const items = await res.json();
        const currentItem = items.find(i => i.product_id === productId);
        if (!currentItem) return;

        const newQty = currentItem.quantity + delta;
        if (newQty <= 0) {
            await removeItemFromCart(productId, false);
        } else {
            // Update quantity by adding delta
            await fetch(`${API_BASE}/api/cart/items`, {
                method: 'POST',
                headers: getHeaders(),
                body: JSON.stringify({
                    product_id: productId,
                    name: currentItem.name,
                    price: Number(currentItem.price),
                    quantity: delta
                })
            });
        }
        await updateCartCount();
        await renderCartDrawer();
    } catch (err) {
        showToast('Could not update quantity: ' + err.message, 'error');
    }
}

async function removeItemFromCart(productId, notify = true) {
    try {
        const res = await fetch(`${API_BASE}/api/cart/items/${productId}`, {
            method: 'DELETE',
            headers: getHeaders()
        });
        if (!res.ok && res.status !== 404) throw new Error(`HTTP ${res.status}`);

        if (notify) showToast('Item removed from cart', 'info');
        await updateCartCount();
        await renderCartDrawer();
    } catch (err) {
        showToast('Failed to remove: ' + err.message, 'error');
    }
}

async function updateCartCount(bump = false) {
    try {
        const res = await fetch(`${API_BASE}/api/cart/items`, { headers: getHeaders() });
        if (!res.ok) return;
        const items = await res.json();
        const count = items.reduce((sum, item) => sum + (item.quantity || 1), 0);

        const counterEl = document.getElementById('cart-count');
        if (counterEl) {
            counterEl.textContent = count;
            if (bump) {
                counterEl.classList.add('bump');
                setTimeout(() => counterEl.classList.remove('bump'), 300);
            }
        }
    } catch {
        /* ignore offline errors */
    }
}

async function renderCartDrawer() {
    const container = document.getElementById('cart-items-container');
    const subtotalEl = document.getElementById('cart-subtotal');
    const totalEl = document.getElementById('cart-total-price');
    const checkoutBtn = document.getElementById('checkout-btn');

    try {
        const res = await fetch(`${API_BASE}/api/cart/items`, { headers: getHeaders() });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const items = await res.json();

        if (!items || items.length === 0) {
            container.innerHTML = `
                <div class="cart-empty-view">
                    <div class="empty-icon-wrap">
                        <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <circle cx="8" cy="21" r="1"/><circle cx="19" cy="21" r="1"/>
                            <path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12"/>
                        </svg>
                    </div>
                    <h4>Your cart is empty</h4>
                    <p>Add items from the hardware catalog to populate your cart session in Redis.</p>
                </div>
            `;
            if (subtotalEl) subtotalEl.textContent = '$0.00';
            if (totalEl) totalEl.textContent = '$0.00';
            if (checkoutBtn) checkoutBtn.disabled = true;
            return;
        }

        let total = 0;
        container.innerHTML = items.map(item => {
            const sub = Number(item.price) * Number(item.quantity);
            total += sub;

            return `
                <div class="cart-item-card">
                    <div class="item-main">
                        <strong>${escapeHtml(item.name)}</strong>
                        <span class="item-unit-price">$${Number(item.price).toFixed(2)} each</span>
                    </div>

                    <div class="item-controls">
                        <div class="qty-counter">
                            <button class="qty-btn" onclick="updateItemQuantity(${item.product_id}, -1)">&minus;</button>
                            <span class="qty-value">${item.quantity}</span>
                            <button class="qty-btn" onclick="updateItemQuantity(${item.product_id}, 1)">&#43;</button>
                        </div>
                        <span class="item-subtotal">$${sub.toFixed(2)}</span>
                        <button style="background:none; border:none; color:#ef4444; cursor:pointer; padding:4px;" 
                                onclick="removeItemFromCart(${item.product_id})" title="Delete item">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
                            </svg>
                        </button>
                    </div>
                </div>
            `;
        }).join('');

        if (subtotalEl) subtotalEl.textContent = `$${total.toFixed(2)}`;
        if (totalEl) totalEl.textContent = `$${total.toFixed(2)}`;
        if (checkoutBtn) checkoutBtn.disabled = false;
    } catch (err) {
        container.innerHTML = `<p style="color:#ef4444; text-align:center; padding:20px;">Error loading cart: ${escapeHtml(err.message)}</p>`;
        if (checkoutBtn) checkoutBtn.disabled = true;
    }
}

// Order Checkout Flow
async function checkout() {
    const btn = document.getElementById('checkout-btn');
    if (!btn || btn.disabled) return;

    btn.disabled = true;
    btn.innerHTML = `
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="animation:spin 1s linear infinite">
            <circle cx="12" cy="12" r="10" stroke-opacity="0.25"/><path d="M12 2a10 10 0 0 1 10 10"/>
        </svg>
        <span>Processing Order...</span>
    `;

    try {
        const cartRes = await fetch(`${API_BASE}/api/cart/items`, { headers: getHeaders() });
        if (!cartRes.ok) throw new Error('Could not read cart contents');
        const cartItems = await cartRes.json();
        if (!cartItems || cartItems.length === 0) {
            showToast('Your cart is empty', 'error');
            return;
        }

        const payload = {
            session_id: currentSessionId,
            items: cartItems.map(i => ({
                product_id: i.product_id,
                name: i.name,
                price: Number(i.price),
                quantity: Number(i.quantity)
            }))
        };

        const orderRes = await fetch(`${API_BASE}/api/orders`, {
            method: 'POST',
            headers: getHeaders(),
            body: JSON.stringify(payload)
        });

        if (!orderRes.ok) {
            const errTxt = await orderRes.text();
            throw new Error(`Order rejected (HTTP ${orderRes.status}): ${errTxt}`);
        }

        const order = await orderRes.json();

        // Atomically clear cart in Redis
        await fetch(`${API_BASE}/api/cart`, {
            method: 'DELETE',
            headers: getHeaders()
        });

        await updateCartCount();
        closeCartDrawer();
        showToast(`Order #${order.id} placed! Total: $${Number(order.total).toFixed(2)}`, 'success');
        openOrdersModal();
    } catch (err) {
        showToast('Checkout failed: ' + err.message, 'error');
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = `
                <span class="btn-text">Confirm &amp; Place Order</span>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>
                </svg>
            `;
        }
    }
}

// Order History View
async function renderOrdersModal() {
    const container = document.getElementById('orders-container');
    container.innerHTML = '<div class="loading-state" style="text-align:center; padding:30px; color:#94a3b8;">Querying order records...</div>';

    try {
        const res = await fetch(`${API_BASE}/api/orders`, { headers: getHeaders() });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const orders = await res.json();

        if (!orders || orders.length === 0) {
            container.innerHTML = `
                <div style="text-align:center; padding:40px 10px; color:var(--text-muted);">
                    <h4>No orders found</h4>
                    <p style="margin-top:6px; font-size:0.85rem;">Add products and complete checkout to see order records saved to PostgreSQL.</p>
                </div>
            `;
            return;
        }

        container.innerHTML = orders.map(o => {
            const dateStr = new Date(o.created_at).toLocaleString();
            const items = o.items || [];

            return `
                <div class="order-history-card">
                    <div class="order-history-header">
                        <strong style="color:#fff; font-size:1.05rem;">Order #${o.id}</strong>
                        <span class="order-badge confirmed">${escapeHtml(o.status)}</span>
                    </div>
                    <div class="order-timestamp">Placed: ${dateStr}</div>
                    <div class="order-line-items">
                        ${items.map(i => `
                            <div style="display:flex; justify-content:space-between; margin-bottom:4px;">
                                <span>${escapeHtml(i.name)} &times; ${i.quantity}</span>
                                <span>$${(Number(i.price) * Number(i.quantity)).toFixed(2)}</span>
                            </div>
                        `).join('')}
                    </div>
                    <div class="order-total-row">
                        <span>Total</span>
                        <span style="color:#10b981;">$${Number(o.total).toFixed(2)}</span>
                    </div>
                </div>
            `;
        }).join('');
    } catch (err) {
        container.innerHTML = `<p style="color:#ef4444; padding:20px; text-align:center;">Failed to load order history: ${escapeHtml(err.message)}</p>`;
    }
}

// Modal & Drawer Toggles
function isDrawerOpen() {
    const drawer = document.getElementById('cart-drawer');
    return drawer && drawer.classList.contains('active');
}

function openCartDrawer() {
    const drawer = document.getElementById('cart-drawer');
    const overlay = document.getElementById('cart-drawer-overlay');
    if (drawer && overlay) {
        drawer.classList.add('active');
        overlay.classList.add('active');
        renderCartDrawer();
    }
}

function closeCartDrawer() {
    const drawer = document.getElementById('cart-drawer');
    const overlay = document.getElementById('cart-drawer-overlay');
    if (drawer && overlay) {
        drawer.classList.remove('active');
        overlay.classList.remove('active');
    }
}

function openOrdersModal() {
    const modal = document.getElementById('orders-modal');
    if (modal) {
        modal.classList.add('active');
        renderOrdersModal();
    }
}

function closeOrdersModal() {
    const modal = document.getElementById('orders-modal');
    if (modal) modal.classList.remove('active');
}

function openArchitectureModal() {
    const modal = document.getElementById('arch-modal');
    if (modal) modal.classList.add('active');
}

function closeArchitectureModal() {
    const modal = document.getElementById('arch-modal');
    if (modal) modal.classList.remove('active');
}

// Escape HTML utility
function escapeHtml(s) {
    if (s === null || s === undefined) return '';
    const d = document.createElement('div');
    d.textContent = String(s);
    return d.innerHTML;
}

// Close modals when clicking outside
window.addEventListener('click', (e) => {
    const ordersModal = document.getElementById('orders-modal');
    const archModal = document.getElementById('arch-modal');
    if (e.target === ordersModal) closeOrdersModal();
    if (e.target === archModal) closeArchitectureModal();
});

// Initialize UI
initSessionUI();
loadProducts();
updateCartCount();
