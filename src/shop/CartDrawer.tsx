import { Minus, Plus, ShoppingBag, X } from 'lucide-react';
import { type CartItem, money } from '@/lib/types';

type Props = {
  cart: CartItem[];
  subtotal: number;
  onClose: () => void;
  onChange: (index: number, delta: number) => void;
  onCheckout: () => void;
};

export default function CartDrawer({ cart, subtotal, onClose, onChange, onCheckout }: Props) {
  const count = cart.reduce((n, item) => n + item.quantity, 0);
  return (
    <div className="sf-overlay sf-overlay-drawer" onMouseDown={onClose}>
      <aside className="sf-drawer" role="dialog" aria-modal="true" aria-label="Your bag" onMouseDown={(e) => e.stopPropagation()}>
        <header className="sf-drawer-head">
          <h2>Your bag{count > 0 && <span> ({count})</span>}</h2>
          <button className="sf-close sf-close-inline" onClick={onClose} aria-label="Close bag"><X size={20} /></button>
        </header>
        {cart.length === 0 ? (
          <div className="sf-empty">
            <ShoppingBag size={36} />
            <h3>Your bag is empty</h3>
            <p>Pick something from the shop and it will appear here.</p>
            <button className="sf-btn sf-btn-primary" onClick={onClose}>Browse the shop</button>
          </div>
        ) : (
          <>
            <ul className="sf-lines">
              {cart.map((item, index) => (
                <li key={`${item.id}-${item.size}-${item.color}`} className="sf-line-item">
                  <img src={item.image_url} alt="" width={160} height={200} loading="lazy" />
                  <div className="sf-line-info">
                    <h3>{item.name}</h3>
                    <p>{[item.color, item.size].filter(Boolean).join(' / ')}</p>
                    <div className="sf-qty" role="group" aria-label={`Quantity for ${item.name}`}>
                      <button onClick={() => onChange(index, -1)} aria-label="Remove one"><Minus size={16} /></button>
                      <span>{item.quantity}</span>
                      <button onClick={() => onChange(index, 1)} aria-label="Add one"><Plus size={16} /></button>
                    </div>
                  </div>
                  <strong className="sf-price">{money(item.price * item.quantity)}</strong>
                </li>
              ))}
            </ul>
            <footer className="sf-drawer-foot">
              <div className="sf-sum"><span>Subtotal</span><strong>{money(subtotal)}</strong></div>
              <div className="sf-sum sf-sum-soft"><span>Delivery</span><span>Worked out at checkout</span></div>
              <button className="sf-btn sf-btn-primary sf-btn-block" onClick={onCheckout}>Go to checkout</button>
            </footer>
          </>
        )}
      </aside>
    </div>
  );
}
