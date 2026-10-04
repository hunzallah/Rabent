import { useState } from 'react';
import { ShoppingBag, X } from 'lucide-react';
import { type Product, money } from '@/lib/types';

type Variant = { size: string; color: string; price_override: number | null };

type Props = {
  product: Product;
  variants: Variant[];
  categoryName?: string;
  onClose: () => void;
  onAdd: (product: Product, size?: string, color?: string, price?: number) => void;
};

export default function ProductModal({ product, variants, categoryName, onClose, onAdd }: Props) {
  const sizeList = product.sizes.length ? product.sizes : Array.from(new Set(variants.map((v) => v.size)));
  const [size, setSize] = useState(sizeList[0] ?? '');
  const [color, setColor] = useState(product.colors[0] ?? '');
  const price = variants.find((v) => v.size === size && v.price_override !== null)?.price_override ?? product.price;
  const soldOut = product.inventory <= 0;

  return (
    <div className="sf-overlay sf-overlay-sheet" onMouseDown={onClose}>
      <div className="sf-product" role="dialog" aria-modal="true" aria-label={product.name} onMouseDown={(e) => e.stopPropagation()}>
        <button className="sf-close" onClick={onClose} aria-label="Close"><X size={20} /></button>
        <div className="sf-product-media"><img src={product.image_url} alt={product.name} width={800} height={1000} /></div>
        <div className="sf-product-body">
          <div className="sf-product-scroll">
            {categoryName && <p className="sf-crumb">{categoryName}</p>}
            <h2 className="sf-h2">{product.name}</h2>
            <p className="sf-price sf-price-lg">{money(price)}{product.compare_at_price ? <del>{money(product.compare_at_price)}</del> : null}</p>
            {product.description && <p className="sf-desc">{product.description}</p>}
            {product.colors.length > 0 && (
              <fieldset className="sf-options">
                <legend>Colour <b>{color}</b></legend>
                <div>{product.colors.map((c) => <button key={c} type="button" className={c === color ? 'is-picked' : ''} aria-pressed={c === color} onClick={() => setColor(c)}>{c}</button>)}</div>
              </fieldset>
            )}
            {sizeList.length > 0 && (
              <fieldset className="sf-options">
                <legend>Size <b>{size}</b></legend>
                <div>{sizeList.map((s) => <button key={s} type="button" className={s === size ? 'is-picked' : ''} aria-pressed={s === size} onClick={() => setSize(s)}>{s}</button>)}</div>
              </fieldset>
            )}
            {!soldOut && product.inventory <= 5 && <p className="sf-stock">Only {product.inventory} left</p>}
          </div>
          <div className="sf-product-foot">
            <button className="sf-btn sf-btn-primary sf-btn-block" disabled={soldOut} onClick={() => onAdd(product, size, color, price)}>
              <ShoppingBag size={18} /> {soldOut ? 'Sold out' : `Add to bag · ${money(price)}`}
            </button>
            <p className="sf-note">Delivery charge is worked out at checkout.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
