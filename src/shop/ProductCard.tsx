import { Heart, Plus } from 'lucide-react';
import { type Product, money } from '@/lib/types';

type Props = {
  product: Product;
  saved: boolean;
  priority?: boolean;
  onOpen: (product: Product) => void;
  onAdd: (product: Product) => void;
  onToggleSaved: (id: string) => void;
};

export default function ProductCard({ product, saved, priority, onOpen, onAdd, onToggleSaved }: Props) {
  const soldOut = product.inventory <= 0;
  const needsChoice = product.sizes.length > 1 || product.colors.length > 1;
  const low = !soldOut && product.inventory <= 5;

  return (
    <article className="sf-card">
      <div className="sf-card-media">
        <button className="sf-card-open" onClick={() => onOpen(product)} aria-label={`View ${product.name}`}>
          <img
            src={product.image_url}
            alt={product.name}
            width={800}
            height={1000}
            loading={priority ? 'eager' : 'lazy'}
            decoding="async"
          />
        </button>
        {soldOut ? <span className="sf-tag sf-tag-out">Sold out</span> : product.compare_at_price ? <span className="sf-tag sf-tag-sale">Sale</span> : null}
        <button
          className={`sf-heart ${saved ? 'is-saved' : ''}`}
          onClick={() => onToggleSaved(product.id)}
          aria-label={saved ? `Remove ${product.name} from saved` : `Save ${product.name}`}
          aria-pressed={saved}
        >
          <Heart size={18} fill={saved ? 'currentColor' : 'none'} />
        </button>
        {!soldOut && (
          <button
            className="sf-add"
            onClick={() => (needsChoice ? onOpen(product) : onAdd(product))}
            aria-label={needsChoice ? `Choose options for ${product.name}` : `Add ${product.name} to bag`}
          >
            <Plus size={20} />
          </button>
        )}
      </div>
      <div className="sf-card-info">
        <h3 className="sf-card-name"><button onClick={() => onOpen(product)}>{product.name}</button></h3>
        <p className="sf-price">
          {money(product.price)}
          {product.compare_at_price ? <del>{money(product.compare_at_price)}</del> : null}
        </p>
        {low && <p className="sf-stock">Only {product.inventory} left</p>}
      </div>
    </article>
  );
}
