import { useEffect, useState } from 'react';
import { ArrowLeft, Package, ShoppingBag, X } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { type Order, type OrderItem, money, formatDate, formatTime, STATUS_STYLES } from '@/lib/types';

export default function CustomerOrders({ onClose }: { onClose: () => void }) {
  const [orders, setOrders] = useState<Order[]>([]);
  const [items, setItems] = useState<Record<string, OrderItem[]>>({});
  const [expanded, setExpanded] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      const { data, error } = await supabase
        .from('orders')
        .select('*')
        .order('created_at', { ascending: false });
      if (!error && data) setOrders(data as Order[]);
      setLoading(false);
    };
    void load();
  }, []);

  const toggleExpand = async (orderId: string) => {
    if (expanded === orderId) { setExpanded(null); return; }
    setExpanded(orderId);
    if (!items[orderId]) {
      const { data } = await supabase.from('order_items').select('*').eq('order_id', orderId);
      if (data) setItems((prev) => ({ ...prev, [orderId]: data as OrderItem[] }));
    }
  };

  return (
    <div className="admin-shell">
      <aside className="admin-sidebar">
        <div className="admin-brand">
          <span className="admin-logo">RABBENT<span>.</span></span>
          <p className="admin-sublabel">My Orders</p>
        </div>
        <nav className="admin-nav">
          <button className="active">
            <ShoppingBag size={18} /> Order History
          </button>
        </nav>
        <button className="admin-exit" onClick={onClose}>
          <ArrowLeft size={16} /> Back to store
        </button>
        <button className="admin-signout" onClick={async () => { await supabase.auth.signOut(); onClose(); }}>
          <X size={16} /> Sign out
        </button>
      </aside>

      <div className="admin-main">
        <header className="admin-topbar">
          <div>
            <h1>Your Orders</h1>
            <p>{orders.length} {orders.length === 1 ? 'order' : 'orders'} placed</p>
          </div>
        </header>

        {loading ? (
          <div className="admin-loading">Loading your orders...</div>
        ) : orders.length === 0 ? (
          <div className="admin-empty large">
            <Package size={32} />
            <p style={{ marginTop: 16 }}>You haven't placed any orders yet.</p>
          </div>
        ) : (
          <div className="admin-card no-pad">
            <table className="admin-table expandable">
              <thead><tr><th>Order</th><th>Date</th><th>Items</th><th>Total</th><th>Status</th></tr></thead>
              <tbody>
                {orders.map((order) => (
                  <>
                    <tr key={order.id} className="order-row" onClick={() => toggleExpand(order.id)}>
                      <td><strong>#{order.id.slice(0, 8)}</strong></td>
                      <td>{formatDate(order.created_at)}<span className="admin-sub">{formatTime(order.created_at)}</span></td>
                      <td><X size={16} className={expanded === order.id ? 'chev-open' : ''} /></td>
                      <td><strong>{money(order.total)}</strong></td>
                      <td><span className={`status-pill ${STATUS_STYLES[order.status] ?? 'status-pending'}`}>{order.status}</span></td>
                    </tr>
                    {expanded === order.id && (
                      <tr className="order-expand-row" key={`${order.id}-expand`}>
                        <td colSpan={5}>
                          <div className="order-detail">
                            <div className="order-detail-info">
                              <div><span className="admin-sub">Delivery address</span><p>{order.address}{order.city ? `, ${order.city}` : ''}{order.postal_code ? ` ${order.postal_code}` : ''}</p></div>
                              <div><span className="admin-sub">Phone</span><p>{order.phone || '—'}</p></div>
                              <div><span className="admin-sub">Payment</span><p>{order.payment_method}</p></div>
                              <div><span className="admin-sub">Subtotal</span><p>{money(order.subtotal)}</p></div>
                              <div><span className="admin-sub">Delivery</span><p>{money(order.delivery_fee)}</p></div>
                              <div><span className="admin-sub">Total</span><p><strong>{money(order.total)}</strong></p></div>
                            </div>
                            <div className="order-items-list">
                              <h4>Items</h4>
                              {items[order.id]?.length ? items[order.id].map((item) => (
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
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
