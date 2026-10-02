import CrudPanel, { type Field } from '@/CrudPanel';
import { useEffect, useState } from 'react';
import { ArrowRight, Box, Check, ChevronDown, Edit3, Plus, Search, ShoppingBag, Trash2, TrendingUp, Truck, Users, X, Package, Tag, LayoutDashboard, LogOut, ArrowLeft } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { type Product, type Category, type Order, type OrderItem, type AdminRole, ORDER_STATUSES, STATUS_STYLES, money, formatDate, formatTime } from '@/lib/types';

type AdminView = 'overview' | 'orders' | 'products' | 'categories' | 'customers' | 'coupons' | 'banners' | 'reviews' | 'variants' | 'addresses';

const t = (key: string, label: string): Field => ({ key, label });
const CRUD = {
  coupons: { table: 'coupons', fields: [{ ...t('code', 'Code'), required: true }, { key: 'percent_off', label: '% off', type: 'number' }, { key: 'active', label: 'Active', type: 'checkbox' }, { key: 'expires_at', label: 'Expires', type: 'datetime-local' }] as Field[] },
  banners: { table: 'banners', fields: [{ ...t('title', 'Title'), required: true }, t('subtitle', 'Subtitle'), { key: 'active', label: 'Active', type: 'checkbox' }, { key: 'display_order', label: 'Order', type: 'number' }] as Field[] },
  reviews: { table: 'reviews', fields: [t('author', 'Author'), { key: 'rating', label: 'Rating', type: 'number' }, t('body', 'Review')] as Field[] },
  variants: { table: 'product_variants', fields: [{ key: 'product_id', label: 'Product', type: 'product' }, { ...t('size', 'Size'), required: true }, { ...t('color', 'Color (e.g. Grey)'), required: true }, { key: 'stock', label: 'Stock', type: 'number' }, { key: 'price_override', label: 'Price for this size', type: 'number', optional: true }] as Field[] },
  addresses: { table: 'addresses', fields: [t('label', 'Label'), t('address', 'Address'), t('city', 'City'), { key: 'latitude', label: 'Lat', type: 'number' }, { key: 'longitude', label: 'Lng', type: 'number' }] as Field[] },
};
export default function AdminDashboard({ onExit }: { onExit: () => void }) {
  const [view, setView] = useState<AdminView>('overview');
  const [orders, setOrders] = useState<Order[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [customers, setCustomers] = useState<CustomerInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState('');
  const [adminEmail, setAdminEmail] = useState('');
  const [adminRole, setAdminRole] = useState<AdminRole | null>(null);

  useEffect(() => {
    (async () => {
      const { data: session } = await supabase.auth.getSession();
      if (session.session?.user?.email) setAdminEmail(session.session.user.email);
      const { data: roleData } = await supabase.rpc('admin_role').maybeSingle();
      if (roleData) setAdminRole(roleData as AdminRole);
    })();
  }, []);

  useEffect(() => {
    const load = async () => {
      const [{ data: orderData }, { data: productData }, { data: categoryData }] = await Promise.all([
        supabase.from('orders').select('*').order('created_at', { ascending: false }),
        supabase.from('products').select('*').order('created_at', { ascending: false }),
        supabase.from('categories').select('*').order('display_order', { ascending: true }),
      ]);
      if (orderData) setOrders(orderData as Order[]);
      if (productData) setProducts(productData as Product[]);
      if (categoryData) setCategories(categoryData as Category[]);
      setLoading(false);
    };
    void load();
  }, []);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(''), 2800);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const canManageProducts = adminRole === 'super_admin' || adminRole === 'inventory_manager';
  const canManageOrders = adminRole === 'super_admin' || adminRole === 'order_manager';
  const isSuperAdmin = adminRole === 'super_admin';

  const stats = {
    revenue: orders.filter((o) => o.status !== 'cancelled').reduce((sum, o) => sum + Number(o.total), 0),
    pending: orders.filter((o) => o.status === 'pending' || o.status === 'confirmed').length,
    delivered: orders.filter((o) => o.status === 'delivered').length,
    lowStock: products.filter((p) => p.inventory <= 15).length,
    orderCount: orders.length,
    productCount: products.length,
  };

  const refreshOrders = async () => {
    const { data } = await supabase.from('orders').select('*').order('created_at', { ascending: false });
    if (data) setOrders(data as Order[]);
  };
  const refreshProducts = async () => {
    const { data } = await supabase.from('products').select('*').order('created_at', { ascending: false });
    if (data) setProducts(data as Product[]);
  };
  const refreshCategories = async () => {
    const { data } = await supabase.from('categories').select('*').order('display_order', { ascending: true });
    if (data) setCategories(data as Category[]);
  };

  const loadCustomers = async () => {
    const { data } = await supabase.from('orders').select('customer_name, email, phone').order('created_at', { ascending: false });
    if (data) {
      const unique = new Map<string, CustomerInfo>();
      for (const o of data as Order[]) {
        if (o.email && !unique.has(o.email)) {
          unique.set(o.email, { name: o.customer_name, email: o.email, phone: o.phone, orderCount: 0 });
        }
        if (unique.has(o.email)) unique.get(o.email)!.orderCount++;
      }
      setCustomers(Array.from(unique.values()));
    }
  };

  return (
    <div className="admin-shell">
      <aside className="admin-sidebar">
        <div className="admin-brand">
          <span className="admin-logo">RABBENT<span>.</span></span>
          <p className="admin-sublabel">Studio Console</p>
        </div>
        <nav className="admin-nav">
          <button className={view === 'overview' ? 'active' : ''} onClick={() => setView('overview')}>
            <LayoutDashboard size={18} /> Overview
          </button>
          <button className={view === 'orders' ? 'active' : ''} onClick={() => setView('orders')}>
            <ShoppingBag size={18} /> Orders
            {stats.pending > 0 && <span className="admin-badge">{stats.pending}</span>}
          </button>
          <button className={view === 'products' ? 'active' : ''} onClick={() => setView('products')}>
            <Package size={18} /> Products
          </button>
          {isSuperAdmin && (['coupons','banners','reviews','variants','addresses'] as const).map((v) => <button key={v} className={view === v ? 'active' : ''} onClick={() => setView(v)}><span style={{textTransform:'capitalize'}}>{v}</span></button>)}
          {isSuperAdmin && (
            <button className={view === 'categories' ? 'active' : ''} onClick={() => setView('categories')}>
              <Tag size={18} /> Categories
            </button>
          )}
          {isSuperAdmin && (
            <button className={view === 'customers' ? 'active' : ''} onClick={() => { setView('customers'); loadCustomers(); }}>
              <Users size={18} /> Customers
            </button>
          )}
        </nav>
        <button className="admin-exit" onClick={onExit}>
          <ArrowLeft size={16} /> Back to store
        </button>
        <button className="admin-signout" onClick={async () => { await supabase.auth.signOut(); onExit(); }}>
          <LogOut size={16} /> Sign out
        </button>
      </aside>

      <div className="admin-main">
        <header className="admin-topbar">
          <div>
            <h1>{view === 'overview' ? 'Overview' : view === 'orders' ? 'Orders' : view === 'products' ? 'Products' : view === 'categories' ? 'Categories' : 'Customers'}</h1>
            <p>{view === 'overview' ? 'Your store at a glance' : view === 'orders' ? `${stats.orderCount} total orders` : view === 'products' ? `${stats.productCount} products in catalog` : view === 'categories' ? `${categories.length} categories` : 'Customer directory'}</p>
          </div>
          <div className="admin-topbar-right">
            <div className="admin-user">
              <span className="admin-user-avatar">{adminEmail.charAt(0).toUpperCase() || 'A'}</span>
              <div><strong>{adminEmail || 'Admin'}</strong><span className="admin-sub">{adminRole?.replace('_', ' ') || 'Store manager'}</span></div>
            </div>
          </div>
        </header>

        {loading ? (
          <div className="admin-loading">Loading your dashboard...</div>
        ) : (
          <>
            {view === 'overview' && <OverviewView stats={stats} orders={orders} products={products} onGoOrders={() => setView('orders')} onGoProducts={() => setView('products')} />}
            {view === 'orders' && <OrdersView orders={orders} onRefresh={refreshOrders} onToast={setToast} canManage={canManageOrders} />}
            {view === 'products' && <ProductsView products={products} categories={categories} onRefresh={refreshProducts} onToast={setToast} canManage={canManageProducts} />}
            {view === 'categories' && isSuperAdmin && <CategoriesView categories={categories} onRefresh={refreshCategories} onToast={setToast} />}
            {isSuperAdmin && view in CRUD && <CrudPanel key={view} table={CRUD[view as keyof typeof CRUD].table} fields={CRUD[view as keyof typeof CRUD].fields} readOnlyCreate={view === 'reviews' || view === 'addresses'} onToast={setToast} />}
            {view === 'customers' && isSuperAdmin && <CustomersView customers={customers} />}
          </>
        )}
      </div>

      {toast && <div className="admin-toast">{toast}</div>}
    </div>
  );
}

type CustomerInfo = { name: string; email: string; phone: string; orderCount: number };

function OverviewView({ stats, orders, products, onGoOrders, onGoProducts }: {
  stats: { revenue: number; pending: number; delivered: number; lowStock: number; orderCount: number; productCount: number };
  orders: Order[]; products: Product[]; onGoOrders: () => void; onGoProducts: () => void;
}) {
  const recentOrders = orders.slice(0, 5);
  const lowStockProducts = products.filter((p) => p.inventory <= 15).slice(0, 4);

  return (
    <div className="admin-overview">
      <div className="stat-grid">
        <StatCard label="Total revenue" value={money(stats.revenue)} icon={<TrendingUp size={20} />} accent="revenue" />
        <StatCard label="Orders" value={String(stats.orderCount)} icon={<ShoppingBag size={20} />} accent="orders" sub={`${stats.pending} awaiting action`} />
        <StatCard label="Delivered" value={String(stats.delivered)} icon={<Check size={20} />} accent="delivered" />
        <StatCard label="Low stock" value={String(stats.lowStock)} icon={<Box size={20} />} accent="warn" sub="15 units or fewer" />
      </div>

      <div className="overview-columns">
        <div className="admin-card">
          <div className="admin-card-head">
            <h3>Recent orders</h3>
            <button className="text-button" onClick={onGoOrders}>View all <ArrowRight size={14} /></button>
          </div>
          {recentOrders.length ? (
            <table className="admin-table">
              <thead><tr><th>Customer</th><th>Date</th><th>Total</th><th>Status</th></tr></thead>
              <tbody>
                {recentOrders.map((order) => (
                  <tr key={order.id}>
                    <td><strong>{order.customer_name}</strong><span className="admin-sub">{order.email}</span></td>
                    <td>{formatDate(order.created_at)}</td>
                    <td><strong>{money(order.total)}</strong></td>
                    <td><span className={`status-pill ${STATUS_STYLES[order.status] ?? 'status-pending'}`}>{order.status}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : <div className="admin-empty">No orders yet.</div>}
        </div>

        <div className="admin-card">
          <div className="admin-card-head">
            <h3>Low stock alerts</h3>
            <button className="text-button" onClick={onGoProducts}>Manage <ArrowRight size={14} /></button>
          </div>
          {lowStockProducts.length ? (
            <div className="lowstock-list">
              {lowStockProducts.map((product) => (
                <div key={product.id} className="lowstock-item">
                  <img src={product.image_url} alt={product.name} />
                  <div><strong>{product.name}</strong><span>{product.colors.join(' / ')}</span></div>
                  <span className={`stock-count ${product.inventory <= 10 ? 'critical' : 'low'}`}>{product.inventory} left</span>
                </div>
              ))}
            </div>
          ) : <div className="admin-empty">All products are well stocked.</div>}
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, icon, accent, sub }: { label: string; value: string; icon: React.ReactNode; accent: string; sub?: string }) {
  return (
    <div className={`stat-card stat-${accent}`}>
      <div className="stat-icon">{icon}</div>
      <div>
        <p className="stat-label">{label}</p>
        <p className="stat-value">{value}</p>
        {sub && <p className="stat-sub">{sub}</p>}
      </div>
    </div>
  );
}

function OrdersView({ orders, onRefresh, onToast, canManage }: { orders: Order[]; onRefresh: () => void; onToast: (msg: string) => void; canManage: boolean }) {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [expanded, setExpanded] = useState<string | null>(null);
  const [items, setItems] = useState<Record<string, OrderItem[]>>({});

  const filtered = orders.filter((o) => {
    const matchSearch = `${o.customer_name} ${o.email} ${o.id}`.toLowerCase().includes(search.toLowerCase());
    const matchStatus = statusFilter === 'all' || o.status === statusFilter;
    return matchSearch && matchStatus;
  });

  const toggleExpand = async (orderId: string) => {
    if (expanded === orderId) { setExpanded(null); return; }
    setExpanded(orderId);
    if (!items[orderId]) {
      const { data } = await supabase.from('order_items').select('*').eq('order_id', orderId);
      if (data) setItems((prev) => ({ ...prev, [orderId]: data as OrderItem[] }));
    }
  };

  const updateStatus = async (orderId: string, status: string) => {
    const { error } = await supabase.from('orders').update({ status }).eq('id', orderId);
    if (error) { onToast('Could not update order status'); return; }
    onToast(`Order marked as ${status}`);
    onRefresh();
  };

  return (
    <div className="admin-orders">
      <div className="admin-toolbar">
        <div className="search-field"><Search size={16} /><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search by customer or order ID" /></div>
        <div className="status-filter">
          <button className={statusFilter === 'all' ? 'active' : ''} onClick={() => setStatusFilter('all')}>All</button>
          {ORDER_STATUSES.map((s) => <button key={s} className={statusFilter === s ? 'active' : ''} onClick={() => setStatusFilter(s)}>{s}</button>)}
        </div>
      </div>

      {filtered.length ? (
        <div className="admin-card no-pad">
          <table className="admin-table expandable">
            <thead><tr><th>Order</th><th>Customer</th><th>Date</th><th>Items</th><th>Total</th><th>Status</th><th></th></tr></thead>
            <tbody>
              {filtered.map((order) => (
                <OrderRow key={order.id} order={order} expanded={expanded === order.id} items={items[order.id]} onToggle={() => toggleExpand(order.id)} canManage={canManage} onStatusChange={(s) => updateStatus(order.id, s)} />
              ))}
            </tbody>
          </table>
        </div>
      ) : <div className="admin-empty large">No orders match your filters.</div>}
    </div>
  );
}

function OrderRow({ order, expanded, items, onToggle, canManage, onStatusChange }: {
  order: Order; expanded: boolean; items: OrderItem[] | undefined; onToggle: () => void; canManage: boolean; onStatusChange: (s: string) => void;
}) {
  return (
    <>
      <tr className="order-row" onClick={onToggle}>
        <td><strong>#{order.id.slice(0, 8)}</strong></td>
        <td><strong>{order.customer_name}</strong><span className="admin-sub">{order.city || '—'}</span></td>
        <td>{formatDate(order.created_at)}<span className="admin-sub">{formatTime(order.created_at)}</span></td>
        <td><ChevronDown size={16} className={expanded ? 'chev-open' : ''} /></td>
        <td><strong>{money(order.total)}</strong></td>
        <td><span className={`status-pill ${STATUS_STYLES[order.status] ?? 'status-pending'}`}>{order.status}</span></td>
        <td>
          {canManage ? (
            <select
              className="status-select"
              value={order.status}
              onClick={(e) => e.stopPropagation()}
              onChange={(e) => onStatusChange(e.target.value)}
            >
              {ORDER_STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
            </select>
          ) : <span className="admin-sub">—</span>}
        </td>
      </tr>
      {expanded && (
        <tr className="order-expand-row">
          <td colSpan={7}>
            <div className="order-detail">
              <div className="order-detail-info">
                <div><span className="admin-sub">Email</span><p>{order.email}</p></div>
                <div><span className="admin-sub">Phone</span><p>{order.phone || '—'}</p></div>
                <div><span className="admin-sub">Address</span><p>{order.address}{order.city ? `, ${order.city}` : ''}{order.postal_code ? ` ${order.postal_code}` : ''}</p></div>
                <div><span className="admin-sub">Payment</span><p>{order.payment_method}</p></div>
                <div><span className="admin-sub">Subtotal</span><p>{money(order.subtotal)}</p></div>
                <div><span className="admin-sub">Delivery</span><p>{money(order.delivery_fee)}</p></div>
                <div><span className="admin-sub">Total</span><p><strong>{money(order.total)}</strong></p></div>
              </div>
              <div className="order-items-list">
                <h4>Items</h4>
                {items?.length ? items.map((item) => (
                  <div key={item.id} className="order-item-row">
                    <div><strong>{item.product_name}</strong><span>{item.color} / {item.size}</span></div>
                    <span>×{item.quantity}</span>
                    <strong>{money(item.unit_price * item.quantity)}</strong>
                  </div>
                )) : <span className="admin-sub">Loading items...</span>}
              </div>
            </div>
          </td>
        </tr>
      )}
    </>
  );
}

function ProductsView({ products, categories, onRefresh, onToast, canManage }: { products: Product[]; categories: Category[]; onRefresh: () => void; onToast: (msg: string) => void; canManage: boolean }) {
  const [search, setSearch] = useState('');
  const [editing, setEditing] = useState<Product | null>(null);
  const [creating, setCreating] = useState(false);

  const filtered = products.filter((p) => p.name.toLowerCase().includes(search.toLowerCase()));

  const deleteProduct = async (id: string) => {
    const { error } = await supabase.from('products').delete().eq('id', id);
    if (error) { onToast('Could not delete product'); return; }
    onToast('Product removed');
    onRefresh();
  };

  const toggleActive = async (product: Product) => {
    const { error } = await supabase.from('products').update({ is_active: !product.is_active }).eq('id', product.id);
    if (error) { onToast('Could not update product'); return; }
    onToast(product.is_active ? 'Product hidden' : 'Product visible');
    onRefresh();
  };

  return (
    <div className="admin-products">
      <div className="admin-toolbar">
        <div className="search-field"><Search size={16} /><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search products" /></div>
        {canManage && <button className="button button-dark" onClick={() => setCreating(true)}><Plus size={16} /> Add product</button>}
      </div>

      <div className="admin-card no-pad">
        <table className="admin-table">
          <thead><tr><th>Product</th><th>Category</th><th>Price</th><th>Inventory</th><th>Featured</th><th>Status</th><th></th></tr></thead>
          <tbody>
            {filtered.map((product) => {
              const cat = categories.find((c) => c.id === product.category_id);
              return (
                <tr key={product.id}>
                  <td className="product-cell">
                    <img src={product.image_url} alt={product.name} />
                    <div><strong>{product.name}</strong><span className="admin-sub">{product.colors.join(' / ')}</span></div>
                  </td>
                  <td>{cat?.name ?? '—'}</td>
                  <td><strong>{money(product.price)}</strong>{product.compare_at_price && <span className="admin-sub">was {money(product.compare_at_price)}</span>}</td>
                  <td><span className={`stock-count inline ${product.inventory <= 10 ? 'critical' : product.inventory <= 15 ? 'low' : 'ok'}`}>{product.inventory}</span></td>
                  <td>{product.featured ? <Check size={18} className="check-icon" /> : <span className="admin-sub">—</span>}</td>
                  <td>
                    <button className={`status-pill ${product.is_active ? 'status-delivered' : 'status-cancelled'}`} onClick={() => toggleActive(product)}>
                      {product.is_active ? 'Active' : 'Hidden'}
                    </button>
                  </td>
                  <td className="row-actions">
                    {canManage && <button onClick={() => setEditing(product)} aria-label="Edit"><Edit3 size={16} /></button>}
                    {canManage && <button onClick={() => deleteProduct(product.id)} aria-label="Delete"><Trash2 size={16} /></button>}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {filtered.length === 0 && <div className="admin-empty large">No products found.</div>}

      {editing && canManage && <ProductEditModal product={editing} categories={categories} onClose={() => setEditing(null)} onSaved={() => { onRefresh(); setEditing(null); }} onToast={onToast} />}
      {creating && canManage && <ProductEditModal product={null} categories={categories} onClose={() => setCreating(false)} onSaved={() => { onRefresh(); setCreating(false); }} onToast={onToast} />}
    </div>
  );
}

function ProductEditModal({ product, categories, onClose, onSaved, onToast }: {
  product: Product | null; categories: Category[]; onClose: () => void; onSaved: () => void; onToast: (msg: string) => void;
}) {
  const [form, setForm] = useState({
    name: product?.name ?? '',
    slug: product?.slug ?? '',
    description: product?.description ?? '',
    price: product?.price ?? 0,
    compare_at_price: product?.compare_at_price ?? '',
    image_url: product?.image_url ?? '',
    sizes: product?.sizes.join(', ') ?? 'S, M, L, XL',
    colors: product?.colors.join(', ') ?? 'Black',
    inventory: product?.inventory ?? 0,
    featured: product?.featured ?? false,
    category_id: product?.category_id ?? categories[0]?.id ?? '',
    is_active: product?.is_active ?? true,
  });
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [sizePrices, setSizePrices] = useState<Record<string, string>>({});
  useEffect(() => {
    if (!product) return;
    void supabase.from('product_variants').select('size,price_override').eq('product_id', product.id).then(({ data }) => {
      const m: Record<string, string> = {};
      (data || []).forEach((v) => { if (v.price_override !== null) m[v.size as string] = String(v.price_override); });
      setSizePrices(m);
    });
  }, [product]);

  const uploadImage = async (file: File) => {
    setUploading(true);
    const ext = file.name.split('.').pop();
    const fileName = `${Date.now()}.${ext}`;
    const { error: uploadError } = await supabase.storage.from('product-images').upload(fileName, file);
    if (uploadError) {
      onToast('Could not upload image');
      setUploading(false);
      return;
    }
    const { data: urlData } = supabase.storage.from('product-images').getPublicUrl(fileName);
    setForm({ ...form, image_url: urlData.publicUrl });
    setUploading(false);
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    const payload = {
      name: form.name,
      slug: form.slug || form.name.toLowerCase().replace(/\s+/g, '-'),
      description: form.description,
      price: Number(form.price),
      compare_at_price: form.compare_at_price ? Number(form.compare_at_price) : null,
      image_url: form.image_url,
      sizes: form.sizes.split(',').map((s) => s.trim()).filter(Boolean),
      colors: form.colors.split(',').map((s) => s.trim()).filter(Boolean),
      inventory: Number(form.inventory),
      featured: form.featured,
      category_id: form.category_id || null,
      is_active: form.is_active,
    };
    const { data: saved, error } = product
      ? await supabase.from('products').update(payload).eq('id', product.id).select('id').single()
      : await supabase.from('products').insert(payload).select('id').single();
    if (error || !saved) { onToast('Could not save product'); setSaving(false); return; }
    // Size prices: replace this product's variant rows with the prices typed below.
    await supabase.from('product_variants').delete().eq('product_id', saved.id);
    const rows = payload.sizes.filter((s) => (sizePrices[s] ?? '').trim() !== '')
      .map((s) => ({ product_id: saved.id, size: s, color: payload.colors[0] || 'Any', stock: payload.inventory, price_override: Number(sizePrices[s]) }));
    if (rows.length) {
      const { error: vErr } = await supabase.from('product_variants').insert(rows);
      if (vErr) { onToast('Product saved, but size prices failed: ' + vErr.message); setSaving(false); return; }
    }
    onToast(product ? 'Product updated' : 'Product added to catalog');
    onSaved();
  };

  return (
    <div className="modal-backdrop" onMouseDown={onClose}>
      <div className="admin-edit-modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="admin-edit-head">
          <h2>{product ? 'Edit product' : 'New product'}</h2>
          <button className="close-button" onClick={onClose}><X size={20} /></button>
        </div>
        <form onSubmit={save}>
          <div className="admin-form-grid">
            <label className="wide">Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></label>
            <label>Price (Rs.)<input type="number" value={form.price} onChange={(e) => setForm({ ...form, price: Number(e.target.value) })} required min={0} /></label>
            <label>Compare-at price<input type="number" value={form.compare_at_price} onChange={(e) => setForm({ ...form, compare_at_price: e.target.value })} placeholder="Optional" /></label>
            <label className="wide">Image URL<input value={form.image_url} onChange={(e) => setForm({ ...form, image_url: e.target.value })} required placeholder="https://..." /></label>
            <label className="wide">Or upload an image
              <input type="file" accept="image/*" onChange={(e) => { const f = e.target.files?.[0]; if (f) uploadImage(f); }} disabled={uploading} />
            </label>
            {form.image_url && <div className="wide"><img src={form.image_url} alt="Preview" style={{ width: 120, height: 150, objectFit: 'cover', borderRadius: 8 }} /></div>}
            <label className="wide">Description<textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={3} /></label>
            <label>Sizes (comma-separated)<input value={form.sizes} onChange={(e) => setForm({ ...form, sizes: e.target.value })} /></label>
            <label>Colors (comma-separated)<input value={form.colors} onChange={(e) => setForm({ ...form, colors: e.target.value })} /></label>
            <div className="wide">
              <span style={{ display: 'block', marginBottom: 6 }}>Price for each size (leave blank to use the main price)</span>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(110px, 1fr))', gap: 8 }}>
                {form.sizes.split(',').map((s) => s.trim()).filter(Boolean).map((s) => (
                  <label key={s}>{s}<input type="number" min={0} placeholder={String(form.price)} value={sizePrices[s] ?? ''} onChange={(e) => setSizePrices({ ...sizePrices, [s]: e.target.value })} /></label>
                ))}
              </div>
            </div>
            <label>Inventory<input type="number" value={form.inventory} onChange={(e) => setForm({ ...form, inventory: Number(e.target.value) })} required min={0} /></label>
            <label>Category
              <select value={form.category_id} onChange={(e) => setForm({ ...form, category_id: e.target.value })}>
                {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </label>
            <label className="checkbox-row">
              <input type="checkbox" checked={form.featured} onChange={(e) => setForm({ ...form, featured: e.target.checked })} />
              Featured product
            </label>
            <label className="checkbox-row">
              <input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} />
              Active (visible to customers)
            </label>
          </div>
          <div className="admin-edit-actions">
            <button type="button" className="button button-outline" onClick={onClose}>Cancel</button>
            <button type="submit" className="button button-dark" disabled={saving || uploading}>{saving ? 'Saving...' : uploading ? 'Uploading...' : 'Save product'}</button>
          </div>
        </form>
      </div>
    </div>
  );
}

function CategoriesView({ categories, onRefresh, onToast }: { categories: Category[]; onRefresh: () => void; onToast: (msg: string) => void }) {
  const [editing, setEditing] = useState<Category | null>(null);
  const [creating, setCreating] = useState(false);

  const deleteCategory = async (id: string) => {
    const { error } = await supabase.from('categories').delete().eq('id', id);
    if (error) { onToast('Could not delete category (products may be linked)'); return; }
    onToast('Category deleted');
    onRefresh();
  };

  return (
    <div className="admin-products">
      <div className="admin-toolbar">
        <div />
        <button className="button button-dark" onClick={() => setCreating(true)}><Plus size={16} /> Add category</button>
      </div>
      <div className="admin-card no-pad">
        <table className="admin-table">
          <thead><tr><th>Name</th><th>Slug</th><th>Display order</th><th></th></tr></thead>
          <tbody>
            {categories.map((cat) => (
              <tr key={cat.id}>
                <td><strong>{cat.name}</strong></td>
                <td>{cat.slug}</td>
                <td>{cat.display_order}</td>
                <td className="row-actions">
                  <button onClick={() => setEditing(cat)} aria-label="Edit"><Edit3 size={16} /></button>
                  <button onClick={() => deleteCategory(cat.id)} aria-label="Delete"><Trash2 size={16} /></button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {editing && <CategoryEditModal category={editing} onClose={() => setEditing(null)} onSaved={() => { onRefresh(); setEditing(null); }} onToast={onToast} />}
      {creating && <CategoryEditModal category={null} onClose={() => setCreating(false)} onSaved={() => { onRefresh(); setCreating(false); }} onToast={onToast} />}
    </div>
  );
}

function CategoryEditModal({ category, onClose, onSaved, onToast }: {
  category: Category | null; onClose: () => void; onSaved: () => void; onToast: (msg: string) => void;
}) {
  const [form, setForm] = useState({
    name: category?.name ?? '',
    slug: category?.slug ?? '',
    display_order: category?.display_order ?? 0,
  });
  const [saving, setSaving] = useState(false);

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    const payload = {
      name: form.name,
      slug: form.slug || form.name.toLowerCase().replace(/\s+/g, '-'),
      display_order: Number(form.display_order),
    };
    const { error } = category
      ? await supabase.from('categories').update(payload).eq('id', category.id)
      : await supabase.from('categories').insert(payload);
    if (error) { onToast('Could not save category'); setSaving(false); return; }
    onToast(category ? 'Category updated' : 'Category created');
    onSaved();
  };

  return (
    <div className="modal-backdrop" onMouseDown={onClose}>
      <div className="admin-edit-modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="admin-edit-head">
          <h2>{category ? 'Edit category' : 'New category'}</h2>
          <button className="close-button" onClick={onClose}><X size={20} /></button>
        </div>
        <form onSubmit={save}>
          <div className="admin-form-grid">
            <label className="wide">Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></label>
            <label>Slug<input value={form.slug} onChange={(e) => setForm({ ...form, slug: e.target.value })} placeholder="auto-generated if empty" /></label>
            <label>Display order<input type="number" value={form.display_order} onChange={(e) => setForm({ ...form, display_order: Number(e.target.value) })} required min={0} /></label>
          </div>
          <div className="admin-edit-actions">
            <button type="button" className="button button-outline" onClick={onClose}>Cancel</button>
            <button type="submit" className="button button-dark" disabled={saving}>{saving ? 'Saving...' : 'Save category'}</button>
          </div>
        </form>
      </div>
    </div>
  );
}

function CustomersView({ customers }: { customers: CustomerInfo[] }) {
  return (
    <div className="admin-card no-pad">
      <table className="admin-table">
        <thead><tr><th>Name</th><th>Email</th><th>Phone</th><th>Orders</th></tr></thead>
        <tbody>
          {customers.length ? customers.map((c) => (
            <tr key={c.email}>
              <td><strong>{c.name}</strong></td>
              <td>{c.email}</td>
              <td>{c.phone || '—'}</td>
              <td><span className="stock-count inline ok">{c.orderCount}</span></td>
            </tr>
          )) : <tr><td colSpan={4}><div className="admin-empty">No customers yet.</div></td></tr>}
        </tbody>
      </table>
    </div>
  );
}
