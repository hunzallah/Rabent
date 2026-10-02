import { useEffect, useMemo, useState } from 'react';
import { ArrowRight, Check, ChevronDown, Heart, LayoutDashboard, Menu, Search, ShoppingBag, SlidersHorizontal, Sparkles, User, X } from 'lucide-react';
import { supabase, supabaseConfigured } from '@/lib/supabase';
import AdminDashboard from '@/AdminDashboard';
import LocationPicker, { type Pin } from '@/LocationPicker';
import AdminLogin from '@/AdminLogin';
import CustomerAuth from '@/CustomerAuth';
import CustomerOrders from '@/CustomerOrders';
import { type Product, type Category, type CartItem, type Order, type OrderItem, money, formatDate, formatTime, ORDER_STATUSES, STATUS_STYLES } from '@/lib/types';
import type { Session } from '@supabase/supabase-js';

const fallbackProducts: Product[] = [
  { id:'1', name:'Classic Oversized Shirt', slug:'classic-oversized-shirt', description:'A relaxed cotton shirt with an easy, everyday drape. Cut for movement and made to become your most-worn layer.', price:4990, compare_at_price:null, image_url:'https://images.pexels.com/photos/8651009/pexels-photo-8651009.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['S','M','L','XL'], colors:['Black','White'], inventory:42, featured:true, category_id:'new', is_active:true },
  { id:'2', name:'Urban Utility Jacket', slug:'urban-utility-jacket', description:'A structured utility jacket with considered pockets and a soft brushed finish.', price:7490, compare_at_price:8490, image_url:'https://images.pexels.com/photos/26936522/pexels-photo-26936522.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['S','M','L','XL'], colors:['Stone','Black'], inventory:18, featured:true, category_id:'men', is_active:true },
  { id:'3', name:'Essential Hoodie', slug:'essential-hoodie', description:'Heavyweight brushed fleece, dropped shoulders, and a clean tonal finish.', price:5490, compare_at_price:null, image_url:'https://images.pexels.com/photos/6616673/pexels-photo-6616673.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['S','M','L','XL'], colors:['Grey','Black'], inventory:35, featured:true, category_id:'essentials', is_active:true },
  { id:'4', name:'Relaxed Trousers', slug:'relaxed-trousers', description:'High-rise trousers with a generous straight leg and a soft, tailored handfeel.', price:4290, compare_at_price:null, image_url:'https://images.pexels.com/photos/8796462/pexels-photo-8796462.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['S','M','L'], colors:['Black','Moss'], inventory:24, featured:false, category_id:'women', is_active:true },
  { id:'5', name:'Studio Blazer', slug:'studio-blazer', description:'A softly tailored blazer designed to move between work, dinner, and everything after.', price:8990, compare_at_price:null, image_url:'https://images.pexels.com/photos/33401553/pexels-photo-33401553.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['S','M','L','XL'], colors:['Check','Oat'], inventory:15, featured:false, category_id:'women', is_active:true },
  { id:'6', name:'Everyday Rib Top', slug:'everyday-rib-top', description:'A close-fitting ribbed top with a clean neckline and versatile layering weight.', price:2490, compare_at_price:null, image_url:'https://images.pexels.com/photos/34299100/pexels-photo-34299100.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['XS','S','M','L'], colors:['White','Black'], inventory:29, featured:false, category_id:'essentials', is_active:true },
  { id:'7', name:'Classic Logo Cap', slug:'classic-logo-cap', description:'A structured cotton cap with an embroidered Rabbent mark and a clean curved brim.', price:2490, compare_at_price:null, image_url:'https://images.pexels.com/photos/13876038/pexels-photo-13876038.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['One Size'], colors:['Black','Olive'], inventory:30, featured:true, category_id:'caps', is_active:true },
  { id:'8', name:'Sport Six-Panel Cap', slug:'sport-six-panel-cap', description:'A breathable six-panel cap with a pre-curved brim and adjustable strap.', price:2290, compare_at_price:null, image_url:'https://images.pexels.com/photos/13447017/pexels-photo-13447017.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['One Size'], colors:['Beige','White'], inventory:28, featured:false, category_id:'caps', is_active:true },
  { id:'9', name:'Rabbent Canvas Tote', slug:'rabbent-canvas-tote', description:'A heavyweight natural canvas tote with a tonal Rabbent print. Roomy enough for everyday carry.', price:1990, compare_at_price:null, image_url:'https://images.pexels.com/photos/33263825/pexels-photo-33263825.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['One Size'], colors:['Natural'], inventory:45, featured:true, category_id:'souvenirs', is_active:true },
  { id:'10', name:'Studio Ceramic Mug', slug:'studio-ceramic-mug', description:'A matte-glazed ceramic mug in a comfortable 350ml size. Made for slow mornings.', price:1790, compare_at_price:null, image_url:'https://images.pexels.com/photos/21624841/pexels-photo-21624841.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['350ml'], colors:['Ink','Oat'], inventory:38, featured:false, category_id:'souvenirs', is_active:true },
  { id:'11', name:'Rabbent Logo Keychain', slug:'rabbent-logo-keychain', description:'A minimalist brushed-metal keychain with a subtle engraved Rabbent mark.', price:990, compare_at_price:null, image_url:'https://images.pexels.com/photos/13062786/pexels-photo-13062786.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['One Size'], colors:['Silver'], inventory:60, featured:false, category_id:'souvenirs', is_active:true },
  { id:'12', name:'Art Print Postcard Set', slug:'art-print-postcard-set', description:'A set of three art-print postcards featuring Rabbent seasonal photography. Printed on heavy stock.', price:1290, compare_at_price:null, image_url:'https://images.pexels.com/photos/39422921/pexels-photo-39422921.jpeg?auto=compress&cs=tinysrgb&h=650&w=940', sizes:['Set of 3'], colors:['Multi'], inventory:50, featured:false, category_id:'souvenirs', is_active:true },
];
const fallbackCategories: Category[] = [{id:'all',name:'All',slug:'all',display_order:0},{id:'new',name:'New arrivals',slug:'new-arrivals',display_order:1},{id:'women',name:'Women',slug:'women',display_order:2},{id:'men',name:'Men',slug:'men',display_order:3},{id:'essentials',name:'Essentials',slug:'essentials',display_order:4},{id:'caps',name:'Caps',slug:'caps',display_order:5},{id:'souvenirs',name:'Souvenirs',slug:'souvenirs',display_order:6}];

function App() {
  const [products, setProducts] = useState<Product[]>(fallbackProducts);
  const [categories, setCategories] = useState<Category[]>(fallbackCategories);
  const [activeCategory, setActiveCategory] = useState('all');
  const [query, setQuery] = useState('');
  const [cart, setCart] = useState<CartItem[]>(() => { try { return JSON.parse(localStorage.getItem('rabbent-cart') || '[]'); } catch { return []; } });
  const [banner, setBanner] = useState('');
  const [variants, setVariants] = useState<Record<string, { size: string; color: string; price_override: number | null }[]>>({});
  const [wishlist, setWishlist] = useState<string[]>([]);
  const [selected, setSelected] = useState<Product | null>(null);
  const [cartOpen, setCartOpen] = useState(false);
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [sort, setSort] = useState('featured');
  const [toast, setToast] = useState('');
  const [loading, setLoading] = useState(true);
  const [orderPlaced, setOrderPlaced] = useState(false);
  const [showAdmin, setShowAdmin] = useState(false);
  const [adminSession, setAdminSession] = useState<Session | null>(null);
  const [adminAuthLoading, setAdminAuthLoading] = useState(false);
  const [customerSession, setCustomerSession] = useState<Session | null>(null);
  const [showCustomerAuth, setShowCustomerAuth] = useState(false);
  const [showCustomerOrders, setShowCustomerOrders] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      if (data.session) setAdminSession(data.session);
      setCustomerSession(data.session ?? null);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      setAdminSession(session);
      setCustomerSession(session);
    });
    return () => listener.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    const loadProducts = async () => {
      const [{ data: productData }, { data: categoryData }] = await Promise.all([
        supabase.from('products').select('*').order('featured', { ascending: false }),
        supabase.from('categories').select('*').order('display_order', { ascending: true }),
      ]);
      if (productData && productData.length > 0) setProducts(productData as Product[]);
      if (categoryData && categoryData.length > 0) {
        setCategories([{id:'all',name:'All',slug:'all',display_order:0}, ...categoryData as Category[]]);
      }
      setLoading(false);
    };
    void loadProducts();
  }, []);
  useEffect(() => { try { localStorage.setItem('rabbent-cart', JSON.stringify(cart)); } catch { /* ignore */ } }, [cart]);
  useEffect(() => { void supabase.from('banners').select('title,subtitle').order('display_order').limit(1).then(({ data }) => { if (data?.[0]) setBanner(`${data[0].title} ${data[0].subtitle ? '· ' + data[0].subtitle : ''}`); }); }, []);
  useEffect(() => { void supabase.from('product_variants').select('product_id,size,color,price_override').then(({ data }) => { const m: typeof variants = {}; (data || []).forEach((v) => { (m[v.product_id as string] ||= []).push({ size: v.size as string, color: v.color as string, price_override: v.price_override === null ? null : Number(v.price_override) }); }); setVariants(m); }); }, []);
  useEffect(() => { if (!customerSession) return; void supabase.from('wishlist_items').select('product_id').then(({ data }) => { if (data) setWishlist(data.map((r) => r.product_id as string)); }); }, [customerSession]);
  useEffect(() => { if (toast) { const timer = window.setTimeout(() => setToast(''), 2600); return () => window.clearTimeout(timer); } }, [toast]);

  const filteredProducts = useMemo(() => {
    const list = products.filter((product) => {
      const matchCategory = activeCategory === 'all' || product.category_id === activeCategory || (activeCategory === 'new' && product.featured);
      return matchCategory && `${product.name} ${product.description}`.toLowerCase().includes(query.toLowerCase());
    });
    return [...list].sort((a,b) => sort === 'low' ? a.price - b.price : sort === 'high' ? b.price - a.price : Number(b.featured) - Number(a.featured));
  }, [products, activeCategory, query, sort]);
  const featured = products.filter((product) => product.featured).slice(0, 3);
  const subtotal = cart.reduce((total, item) => total + item.price * item.quantity, 0);
  const delivery = cart.length ? 250 : 0;

  const addToCart = (product: Product, size = product.sizes[1] || product.sizes[0], color = product.colors[0], price = product.price) => {
    setCart((current) => {
      const existing = current.find((item) => item.id === product.id && item.size === size && item.color === color);
      return existing ? current.map((item) => item === existing ? {...item, quantity: item.quantity + 1} : item) : [...current, {...product, price, quantity:1, size, color}];
    });
    setSelected(null); setToast('Added to your bag');
  };
  const toggleWishlist = (id:string) => { const had = wishlist.includes(id); setWishlist((items) => had ? items.filter((item) => item !== id) : [...items, id]); const uid = customerSession?.user?.id; if (uid) void (had ? supabase.from('wishlist_items').delete().eq('product_id', id) : supabase.from('wishlist_items').insert({ user_id: uid, product_id: id })); };
  const changeQuantity = (id:string, delta:number) => setCart((items) => items.map((item) => item.id === id ? {...item, quantity: Math.max(0, item.quantity + delta)} : item).filter((item) => item.quantity > 0));

  if (showAdmin) {
    if (adminAuthLoading) return null;
    if (!adminSession) return <AdminLogin onClose={() => setShowAdmin(false)} onSuccess={() => setAdminAuthLoading(false)} />;
    return <AdminDashboard onExit={() => setShowAdmin(false)} />;
  }

  if (showCustomerOrders && customerSession) {
    return <CustomerOrders onClose={() => setShowCustomerOrders(false)} />;
  }

  const customerName = customerSession?.user?.user_metadata?.full_name as string || customerSession?.user?.email || '';

  return <div className="app-shell">
    {!supabaseConfigured && <div className="announcement" style={{background:'#b45309'}}>Demo mode: add your Supabase keys to .env to enable login, orders and admin.</div>}
    <div className="announcement">{banner ? banner + ' · ' : ''}Complimentary delivery on orders over Rs. 8,000 <span>•</span> Easy 7-day returns</div>
    <header className="site-header">
      <button className="icon-button mobile-menu" onClick={() => setMenuOpen(!menuOpen)} aria-label="Open menu"><Menu size={20}/></button>
      <a className="logo" href="#top">RABBENT<span>.</span></a>
      <nav className={`main-nav ${menuOpen ? 'is-open' : ''}`}><button onClick={() => {setActiveCategory('all'); document.getElementById('shop')?.scrollIntoView({behavior:'smooth'});}}>Shop</button><button onClick={() => {setActiveCategory('women'); document.getElementById('shop')?.scrollIntoView({behavior:'smooth'});}}>Women</button><button onClick={() => {setActiveCategory('men'); document.getElementById('shop')?.scrollIntoView({behavior:'smooth'});}}>Men</button><button onClick={() => {setActiveCategory('new'); document.getElementById('shop')?.scrollIntoView({behavior:'smooth'});}}>New arrivals</button><button onClick={() => {setActiveCategory('caps'); document.getElementById('shop')?.scrollIntoView({behavior:'smooth'});}}>Caps</button><button onClick={() => {setActiveCategory('souvenirs'); document.getElementById('shop')?.scrollIntoView({behavior:'smooth'});}}>Souvenirs</button></nav>
      <div className="header-actions">
        <button className="icon-button" onClick={() => document.getElementById('shop')?.scrollIntoView({behavior:'smooth'})} aria-label="Search"><Search size={19}/></button>
        <button className="icon-button" onClick={() => setToast('Your wishlist is ready for your next visit')} aria-label="Wishlist"><Heart size={19}/><span className="count-dot">{wishlist.length}</span></button>
        <button className="icon-button" onClick={() => setCartOpen(true)} aria-label="Shopping bag"><ShoppingBag size={19}/><span className="count-dot">{cart.length}</span></button>
        {customerSession ? (
          <button className="icon-button" onClick={() => setShowCustomerOrders(true)} aria-label="My account"><User size={19}/></button>
        ) : (
          <button className="icon-button" onClick={() => setShowCustomerAuth(true)} aria-label="Sign in"><User size={19}/></button>
        )}
        <button className="icon-button admin-toggle" onClick={() => { setShowAdmin(true); setAdminAuthLoading(false); }} aria-label="Admin dashboard"><LayoutDashboard size={19}/></button>
      </div>
    </header>
    <main id="top">
      <section className="hero"><div className="hero-copy"><p className="eyebrow">THE NEW EVERYDAY</p><h1>Modern style.<br/><em>Your way.</em></h1><p>Contemporary essentials for everyday confidence. Designed with intention, made to live in.</p><button className="button button-dark" onClick={() => document.getElementById('shop')?.scrollIntoView({behavior:'smooth'})}>Shop collection <ArrowRight size={16}/></button></div><div className="hero-image"><img src="https://images.pexels.com/photos/5839962/pexels-photo-5839962.jpeg?auto=compress&cs=tinysrgb&h=650&w=940" alt="Rabbent collection in earthy tones"/><div className="hero-caption"><span>SS / 26</span><span>Ease, redefined</span></div></div></section>
      <section className="intro-strip"><p>RABBENT IS A MODERN WARDROBE FOR PEOPLE WHO DRESS WITH PURPOSE.</p><Sparkles size={18}/><p>CONSIDERED PIECES. ENDLESS WAYS TO WEAR.</p></section>
      <section className="section featured-section"><div className="section-heading"><div><p className="eyebrow">CURATED FOR YOU</p><h2>Featured collection</h2></div><button className="text-button" onClick={() => document.getElementById('shop')?.scrollIntoView({behavior:'smooth'})}>View all <ArrowRight size={16}/></button></div><div className="product-grid featured-grid">{featured.map((product) => <ProductCard key={product.id} product={product} wishlist={wishlist} onWishlist={toggleWishlist} onSelect={setSelected} onAdd={addToCart}/>)}</div></section>
      <section className="editorial"><div className="editorial-image"><img src="https://images.pexels.com/photos/37087002/pexels-photo-37087002.jpeg?auto=compress&cs=tinysrgb&h=650&w=940" alt="Neutral streetwear styling"/></div><div className="editorial-copy"><p className="eyebrow">THE RABBENT EDIT</p><h2>Less, but better.</h2><p>Our pieces are designed to make getting dressed feel simple. Clean lines, honest fabrics, and the kind of comfort you reach for without thinking.</p><button className="button button-outline" onClick={() => {setActiveCategory('essentials'); document.getElementById('shop')?.scrollIntoView({behavior:'smooth'});}}>Explore essentials <ArrowRight size={16}/></button></div></section>
      <section className="section shop-section" id="shop"><div className="shop-top"><div><p className="eyebrow">THE COLLECTION</p><h2>Find your everyday</h2></div><div className="shop-tools"><div className="search-field"><Search size={16}/><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search pieces"/></div><select value={sort} onChange={(event) => setSort(event.target.value)}><option value="featured">Featured</option><option value="low">Price: low to high</option><option value="high">Price: high to low</option></select><button className="filter-button"><SlidersHorizontal size={16}/> Filters</button></div></div><div className="category-tabs">{categories.map((category) => <button key={category.id} className={activeCategory === category.id ? 'active' : ''} onClick={() => setActiveCategory(category.id)}>{category.name}</button>)}</div>{loading ? <div className="loading-state">Curating the collection...</div> : <div className="product-grid">{filteredProducts.map((product) => <ProductCard key={product.id} product={product} wishlist={wishlist} onWishlist={toggleWishlist} onSelect={setSelected} onAdd={addToCart}/>)}</div>}{!loading && filteredProducts.length === 0 && <div className="empty-state">No pieces found. Try a different search.</div>}</section>
      <section className="newsletter"><div><p className="eyebrow">STAY IN THE LOOP</p><h2>Good things, in your inbox.</h2></div><form onSubmit={(event) => {event.preventDefault(); setToast('You are on the list');}}><input type="email" required placeholder="Your email address"/><button className="button button-light">Sign me up <ArrowRight size={16}/></button></form></section>
    </main>
    <footer><div className="footer-brand"><a className="logo" href="#top">RABBENT<span>.</span></a><p>Contemporary clothing for every version of you.</p></div><div className="footer-links"><div><strong>Shop</strong><button onClick={() => setActiveCategory('new')}>New arrivals</button><button onClick={() => setActiveCategory('women')}>Women</button><button onClick={() => setActiveCategory('men')}>Men</button><button onClick={() => setActiveCategory('caps')}>Caps</button><button onClick={() => setActiveCategory('souvenirs')}>Souvenirs</button></div><div><strong>Help</strong><button onClick={() => setToast('Shipping is complimentary over Rs. 8,000')}>Shipping & returns</button><button onClick={() => setToast('Reach us at hello@rabbent.com')}>Contact us</button><button onClick={() => setToast('Rabbent care is here for you')}>FAQs</button></div></div><div className="footer-bottom"><span>© 2026 Rabbent Studio</span><span>Made for the everyday.</span></div></footer>
    {selected && <ProductModal variants={variants[selected.id] || []} product={selected} onClose={() => setSelected(null)} onAdd={addToCart}/>} {cartOpen && <CartDrawer cart={cart} subtotal={subtotal} delivery={delivery} onClose={() => setCartOpen(false)} onChange={changeQuantity} onCheckout={() => {setCartOpen(false);setCheckoutOpen(true);}}/>} {checkoutOpen && <CheckoutModal cart={cart} subtotal={subtotal} delivery={delivery} onClose={() => setCheckoutOpen(false)} onPlaced={() => {setCart([]);setCheckoutOpen(false);setOrderPlaced(true);}} customerSession={customerSession} customerName={customerName} />} {orderPlaced && <div className="modal-backdrop"><div className="success-card"><div className="success-icon"><Check size={24}/></div><p className="eyebrow">ORDER CONFIRMED</p><h2>Thank you for shopping Rabbent.</h2><p>Your order is on its way to being prepared. We have saved the details in our order desk.</p><button className="button button-dark" onClick={() => setOrderPlaced(false)}>Continue shopping</button></div></div>} {toast && <div className="toast">{toast}</div>}
    {showCustomerAuth && <CustomerAuth onClose={() => setShowCustomerAuth(false)} onSuccess={() => setShowCustomerAuth(false)} />}
  </div>;
}

function ProductCard({product,wishlist,onWishlist,onSelect,onAdd}:{product:Product;wishlist:string[];onWishlist:(id:string)=>void;onSelect:(product:Product)=>void;onAdd:(product:Product)=>void}) { return <article className="product-card"><div className="product-image" onClick={() => onSelect(product)}><img src={product.image_url} alt={product.name}/>{product.compare_at_price && <span className="sale-tag">Sale</span>}<button className={`heart-button ${wishlist.includes(product.id) ? 'saved' : ''}`} onClick={(event) => {event.stopPropagation();onWishlist(product.id)}} aria-label="Save product"><Heart size={17} fill={wishlist.includes(product.id) ? 'currentColor' : 'none'}/></button><button className="quick-add" onClick={(event) => {event.stopPropagation();onAdd(product)}}>Quick add <ArrowRight size={14}/></button></div><div className="product-meta"><div><h3>{product.name}</h3><p>{product.colors.join(' / ')}</p></div><strong>{money(product.price)}</strong></div></article> }
function ProductModal({product,variants,onClose,onAdd}:{product:Product;variants:{size:string;color:string;price_override:number|null}[];onClose:()=>void;onAdd:(product:Product,size?:string,color?:string,price?:number)=>void}) { const sizeList=product.sizes.length?product.sizes:Array.from(new Set(variants.map((v)=>v.size))); const [size,setSize]=useState(sizeList[1] || sizeList[0]); const price=variants.find((v)=>v.size===size&&v.price_override!==null)?.price_override ?? product.price; const [color,setColor]=useState(product.colors[0]); return <div className="modal-backdrop" onMouseDown={onClose}><div className="product-modal" onMouseDown={(event)=>event.stopPropagation()}><button className="close-button" onClick={onClose}><X size={20}/></button><div className="modal-product-image"><img src={product.image_url} alt={product.name}/></div><div className="modal-product-info"><p className="eyebrow">RABBENT / ESSENTIALS</p><h2>{product.name}</h2><div className="modal-price">{money(price)} {product.compare_at_price && <del>{money(product.compare_at_price)}</del>}</div><p className="description">{product.description}</p><div className="option-block"><span>Color <b>{color}</b></span><div className="swatches">{product.colors.map((item)=> <button key={item} className={color===item?'selected':''} onClick={()=>setColor(item)}>{item}</button>)}</div></div><div className="option-block"><span>Size <b>{size}</b></span><div className="sizes">{sizeList.map((item)=><button key={item} className={size===item?'selected':''} onClick={()=>setSize(item)}>{item}</button>)}</div></div><button className="button button-dark full-button" onClick={()=>onAdd(product,size,color,price)}>Add to bag <ShoppingBag size={16}/></button><p className="modal-note">Free delivery over Rs. 8,000 · Easy 7-day returns</p></div></div></div> }
function CartDrawer({cart,subtotal,delivery,onClose,onChange,onCheckout}:{cart:CartItem[];subtotal:number;delivery:number;onClose:()=>void;onChange:(id:string,delta:number)=>void;onCheckout:()=>void}) { return <div className="drawer-backdrop" onMouseDown={onClose}><aside className="cart-drawer" onMouseDown={(event)=>event.stopPropagation()}><div className="drawer-header"><h2>Your bag <span>{cart.length}</span></h2><button className="close-button" onClick={onClose}><X size={20}/></button></div>{cart.length ? <><div className="cart-items">{cart.map((item)=><div className="cart-item" key={`${item.id}-${item.size}-${item.color}`}><img src={item.image_url} alt={item.name}/><div className="cart-item-info"><div><h3>{item.name}</h3><p>{item.color} / {item.size}</p></div><strong>{money(item.price * item.quantity)}</strong><div className="quantity"><button onClick={()=>onChange(item.id,-1)}>−</button><span>{item.quantity}</span><button onClick={()=>onChange(item.id,1)}>+</button></div></div></div>)}</div><div className="cart-summary"><div><span>Subtotal</span><strong>{money(subtotal)}</strong></div><div><span>Delivery</span><strong>{money(delivery)}</strong></div><div className="total"><span>Total</span><strong>{money(subtotal+delivery)}</strong></div><button className="button button-dark full-button" onClick={onCheckout}>Checkout <ArrowRight size={16}/></button></div></> : <div className="empty-cart"><ShoppingBag size={32}/><h3>Your bag is empty</h3><p>Good things are waiting to be found.</p><button className="button button-outline" onClick={onClose}>Continue shopping</button></div>}</aside></div> }

function CheckoutModal({cart,subtotal,delivery,onClose,onPlaced,customerSession,customerName}:{cart:CartItem[];subtotal:number;delivery:number;onClose:()=>void;onPlaced:()=>void;customerSession:Session|null;customerName:string}) {
  const [submitting,setSubmitting]=useState(false);
  const [error,setError]=useState('');
  const [mapAddress,setMapAddress]=useState('');

  const [pin,setPin]=useState<Pin|null>(null);
  const [coupon,setCoupon]=useState('');
  const [pct,setPct]=useState(0);
  const applyCoupon=async()=>{const {data}=await supabase.rpc('check_coupon',{p_code:coupon});setPct(Number(data)||0);if(!data)setError('That coupon is not valid.');else setError('');};

  const submit = async (event:React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitting(true);
    setError('');
    const form = new FormData(event.currentTarget);
    const finalAddress = (form.get('address') as string) || mapAddress;

    const items = cart.map((item) => ({
      product_id: item.id,
      product_name: item.name,
      size: item.size,
      color: item.color,
      quantity: item.quantity,
      unit_price: item.price,
    }));

    const { data, error: orderError } = await supabase.rpc('place_order', {
      p_items: items,
      p_customer_name: form.get('name'),
      p_email: form.get('email'),
      p_phone: form.get('phone'),
      p_address: finalAddress,
      p_city: form.get('city'),
      p_postal_code: form.get('postal'),
      p_payment_method: 'Cash on Delivery',
      p_customer_id: customerSession?.user?.id || null,
      p_delivery_fee: delivery,
    });

    if (orderError || !data) {
      setError(orderError?.message || 'We could not place your order right now. Please try again.');
      setSubmitting(false);
      return;
    }
    await supabase.rpc('finalize_order',{p_order_id:data,p_coupon:pct?coupon:'',p_lat:pin?.lat??null,p_lng:pin?.lng??null});
    onPlaced();
  };
  const discount=Math.round(subtotal*pct/100);

  return <div className="modal-backdrop"><div className="checkout-modal"><div className="checkout-head"><div><p className="eyebrow">SECURE CHECKOUT</p><h2>Complete your order</h2></div><button className="close-button" onClick={onClose}><X size={20}/></button></div><form onSubmit={submit}>
    <div className="form-grid">
      <label>Full name<input name="name" required placeholder="Your name" defaultValue={customerName} /></label>
      <label>Email address<input type="email" name="email" required placeholder="you@example.com" defaultValue={customerSession?.user?.email || ''} /></label>
      <label>Phone number<input name="phone" required placeholder="+92 300 0000000" /></label>
      <label>Postal code<input name="postal" required placeholder="54000" /></label>
      <label className="wide">Delivery address<input key={mapAddress} name="address" required placeholder="House number, street, area" defaultValue={mapAddress} /></label>
      <label>City<input name="city" required placeholder="Lahore" /></label>
      <label>Payment method<select disabled><option>Cash on Delivery</option></select></label>
    </div>
    <LocationPicker onPick={(p)=>{setPin(p);setMapAddress(p.address);}} />
    <div style={{display:'flex',gap:8,marginBottom:12}}><input value={coupon} onChange={(e)=>setCoupon(e.target.value)} placeholder="Coupon code" style={{flex:1}}/><button type="button" className="button button-outline" onClick={()=>void applyCoupon()}>Apply</button></div>
    <div className="checkout-total"><span>Order total</span><strong>{money(subtotal+delivery-discount)}</strong></div>
    {error && <p className="form-error">{error}</p>}
    <button className="button button-dark full-button" disabled={submitting}>{submitting ? 'Placing order...' : 'Place order'} <ArrowRight size={16}/></button>
  </form></div></div>;
}

export default App;
