const API_BASE = window.location.origin;

function getSessionId() {
    let sid = localStorage.getItem('cloudmart_session_id');
    if (!sid) {
        sid = 'cm_' + Math.random().toString(36).substring(2, 10) + Date.now().toString(36);
        localStorage.setItem('cloudmart_session_id', sid);
    }
    // Sync cookie for backend services that inspect cookies
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

async function loadProducts() {
    const grid = document.getElementById('products-grid');
    try {
        const res = await fetch(`${API_BASE}/api/products`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const products = await res.json();
        if (!products || products.length === 0) {
            grid.innerHTML = '<div class="loading">No products available.</div>';
            return;
        }
        grid.innerHTML = products.map(p => `
            <div class="product-card" data-id="${p.id}">
                <div class="content">
                    <h3>${escapeHtml(p.name)}</h3>
                    <p class="description">${escapeHtml(p.description)}</p>
                    <div class="price">${Number(p.price).toFixed(2)}</div>
                    <button class="btn btn-primary" onclick="addToCart(${p.id}, '${escapeHtml(p.name)}', ${Number(p.price)})">
                        Add to Cart
                    </button>
                </div>
            </div>
        `).join('');
    } catch (err) {
        grid.innerHTML = `<div class="loading error-state">
            Failed to load products: ${escapeHtml(err.message)}
        </div>`;
    }
}

async function addToCart(id, name, price) {
    try {
        const res = await fetch(`${API_BASE}/api/cart/items`, {
            method: 'POST',
            headers: getHeaders(),
            body: JSON.stringify({ product_id: id, name, price: Number(price), quantity: 1 })
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        await updateCartCount();
        openCartModal();
    } catch (err) {
        alert('Failed to add item: ' + err.message);
    }
}

async function removeFromCart(productId) {
    try {
        const res = await fetch(`${API_BASE}/api/cart/items/${productId}`, {
            method: 'DELETE',
            headers: getHeaders()
        });
        if (!res.ok && res.status !== 404) throw new Error(`HTTP ${res.status}`);
        await updateCartCount();
        await renderCartModal();
    } catch (err) {
        alert('Failed to remove item: ' + err.message);
    }
}

async function updateCartCount() {
    try {
        const res = await fetch(`${API_BASE}/api/cart/items`, { headers: getHeaders() });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const items = await res.json();
        const count = items.reduce((s, i) => s + (i.quantity || 1), 0);
        const countEl = document.getElementById('cart-count');
        if (countEl) countEl.textContent = count;
    } catch {
        /* ignore offline errors */
    }
}

async function renderCartModal() {
    const container = document.getElementById('cart-items-container');
    const totalEl = document.getElementById('cart-total-price');
    const checkoutBtn = document.getElementById('checkout-btn');

    try {
        const res = await fetch(`${API_BASE}/api/cart/items`, { headers: getHeaders() });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const items = await res.json();

        if (!items || items.length === 0) {
            container.innerHTML = '<p class="empty-state">Your cart is empty.</p>';
            totalEl.textContent = '$0.00';
            checkoutBtn.disabled = true;
            return;
        }

        let total = 0;
        container.innerHTML = items.map(item => {
            const subtotal = Number(item.price) * Number(item.quantity);
            total += subtotal;
            return `
                <div class="cart-item-row">
                    <div class="cart-item-info">
                        <strong>${escapeHtml(item.name)}</strong>
                        <div class="cart-item-meta">$${Number(item.price).toFixed(2)} × ${item.quantity} = $${subtotal.toFixed(2)}</div>
                    </div>
                    <button class="btn btn-danger btn-sm" onclick="removeFromCart(${item.product_id})">Remove</button>
                </div>
            `;
        }).join('');

        totalEl.textContent = `$${total.toFixed(2)}`;
        checkoutBtn.disabled = false;
    } catch (err) {
        container.innerHTML = `<p class="error-state">Failed to load cart: ${escapeHtml(err.message)}</p>`;
        checkoutBtn.disabled = true;
    }
}

async function checkout() {
    const checkoutBtn = document.getElementById('checkout-btn');
    checkoutBtn.disabled = true;
    checkoutBtn.textContent = 'Processing...';

    try {
        const cartRes = await fetch(`${API_BASE}/api/cart/items`, { headers: getHeaders() });
        if (!cartRes.ok) throw new Error('Could not fetch cart items');
        const cartItems = await cartRes.json();
        if (!cartItems || cartItems.length === 0) {
            alert('Your cart is empty.');
            return;
        }

        const orderPayload = {
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
            body: JSON.stringify(orderPayload)
        });

        if (!orderRes.ok) {
            const errData = await orderRes.text();
            throw new Error(`Order placement failed: HTTP ${orderRes.status} (${errData})`);
        }

        const order = await orderRes.json();

        // Clear cart in backend
        await fetch(`${API_BASE}/api/cart`, {
            method: 'DELETE',
            headers: getHeaders()
        });

        await updateCartCount();
        closeCartModal();
        alert(`Order #${order.id} placed successfully!\nTotal: $${Number(order.total).toFixed(2)}\nStatus: ${order.status}`);
        openOrdersModal();
    } catch (err) {
        alert('Checkout error: ' + err.message);
    } finally {
        checkoutBtn.disabled = false;
        checkoutBtn.textContent = 'Place Order';
    }
}

async function renderOrdersModal() {
    const container = document.getElementById('orders-container');
    container.innerHTML = '<p class="empty-state">Loading order history...</p>';

    try {
        const res = await fetch(`${API_BASE}/api/orders`, { headers: getHeaders() });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const orders = await res.json();

        if (!orders || orders.length === 0) {
            container.innerHTML = '<p class="empty-state">No past orders found for this session.</p>';
            return;
        }

        container.innerHTML = orders.map(o => `
            <div class="order-card">
                <div class="order-header">
                    <strong>Order #${o.id}</strong>
                    <span class="order-status status-${escapeHtml(o.status)}">${escapeHtml(o.status.toUpperCase())}</span>
                </div>
                <div class="order-meta">Placed: ${new Date(o.created_at).toLocaleString()}</div>
                <div class="order-items-summary">
                    ${(o.items || []).map(i => `<div>${escapeHtml(i.name)} × ${i.quantity} ($${Number(i.price).toFixed(2)})</div>`).join('')}
                </div>
                <div class="order-total">Total: <strong>$${Number(o.total).toFixed(2)}</strong></div>
            </div>
        `).join('');
    } catch (err) {
        container.innerHTML = `<p class="error-state">Failed to load orders: ${escapeHtml(err.message)}</p>`;
    }
}

function openCartModal() {
    const modal = document.getElementById('cart-modal');
    if (modal) {
        modal.style.display = 'flex';
        renderCartModal();
    }
}

function closeCartModal() {
    const modal = document.getElementById('cart-modal');
    if (modal) modal.style.display = 'none';
}

function openOrdersModal() {
    const modal = document.getElementById('orders-modal');
    if (modal) {
        modal.style.display = 'flex';
        renderOrdersModal();
    }
}

function closeOrdersModal() {
    const modal = document.getElementById('orders-modal');
    if (modal) modal.style.display = 'none';
}

function showSection(section) {
    if (section === 'products') {
        closeCartModal();
        closeOrdersModal();
        loadProducts();
    }
}

function escapeHtml(s) {
    if (s === null || s === undefined) return '';
    const d = document.createElement('div');
    d.textContent = String(s);
    return d.innerHTML;
}

// Close modals when clicking outside
window.onclick = function(event) {
    const cartModal = document.getElementById('cart-modal');
    const ordersModal = document.getElementById('orders-modal');
    if (event.target === cartModal) closeCartModal();
    if (event.target === ordersModal) closeOrdersModal();
};

initSessionUI();
loadProducts();
updateCartCount();
