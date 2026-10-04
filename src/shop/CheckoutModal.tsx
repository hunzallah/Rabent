import { useEffect, useMemo, useState } from 'react';
import { X } from 'lucide-react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';
import { EASYPAISA_NUMBER, EASYPAISA_ACCOUNT_NAME, easypaisaReady } from '@/lib/config';
import LocationPicker, { type Pin } from '@/LocationPicker';
import { type CartItem, money } from '@/lib/types';

export default function CheckoutModal({cart,onClose,onPlaced,customerSession,customerName}:{cart:CartItem[];onClose:()=>void;onPlaced:(info:{id:string;method:string;total:number})=>void;customerSession:Session|null;customerName:string}) {
  type Quote = { subtotal: number; discount: number; delivery_fee: number; total: number };
  const [submitting,setSubmitting]=useState(false);
  const [error,setError]=useState('');
  const [mapAddress,setMapAddress]=useState('');
  const [pin,setPin]=useState<Pin|null>(null);
  const [coupon,setCoupon]=useState('');
  const [appliedCoupon,setAppliedCoupon]=useState('');
  const [city,setCity]=useState('');
  const [method,setMethod]=useState<'Cash on Delivery'|'Easypaisa'>('Cash on Delivery');
  const [reference,setReference]=useState('');
  const [cities,setCities]=useState<string[]>([]);
  const [quote,setQuote]=useState<Quote|null>(null);
  const [quoteError,setQuoteError]=useState('');

  const items = useMemo(() => cart.map((item) => ({ product_id: item.id, product_name: item.name, size: item.size, color: item.color, quantity: item.quantity })), [cart]);

  useEffect(() => { void supabase.from('delivery_cities').select('city').order('city').then(({ data }) => setCities((data || []).map((r) => r.city as string))); }, []);

  // Ask the database for the price whenever the city, payment method, coupon or bag changes.
  useEffect(() => {
    if (city.trim().length < 2) { setQuote(null); setQuoteError(''); return; }
    let cancelled = false;
    const timer = window.setTimeout(async () => {
      const { data, error: qErr } = await supabase.rpc('quote_delivery', { p_items: items, p_city: city, p_payment_method: method, p_coupon: appliedCoupon });
      if (cancelled) return;
      if (qErr || !data) { setQuote(null); setQuoteError(qErr?.message || 'Could not work out delivery right now.'); return; }
      setQuoteError('');
      setQuote({ subtotal: Number(data.subtotal), discount: Number(data.discount), delivery_fee: Number(data.delivery_fee), total: Number(data.total) });
    }, 350);
    return () => { cancelled = true; window.clearTimeout(timer); };
  }, [items, city, method, appliedCoupon]);

  const applyCoupon=async()=>{
    const code = coupon.trim();
    if (!code) { setAppliedCoupon(''); setError(''); return; }
    const {data}=await supabase.rpc('check_coupon',{p_code:code});
    if (Number(data) > 0) { setAppliedCoupon(code); setError(''); } else { setAppliedCoupon(''); setError('That coupon is not valid.'); }
  };

  const submit = async (event:React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!quote) { setError('Enter your city so we can work out delivery.'); return; }
    setSubmitting(true);
    setError('');
    const form = new FormData(event.currentTarget);
    const finalAddress = (form.get('address') as string) || mapAddress;

    const { data, error: orderError } = await supabase.rpc('place_order', {
      p_items: items,
      p_customer_name: form.get('name'),
      p_email: form.get('email'),
      p_phone: form.get('phone'),
      p_address: finalAddress,
      p_city: city.trim(),
      p_postal_code: form.get('postal'),
      p_payment_method: method,
      p_customer_id: customerSession?.user?.id || null,
      p_coupon: appliedCoupon,
      p_lat: pin?.lat ?? null,
      p_lng: pin?.lng ?? null,
      p_payment_reference: method === 'Easypaisa' ? reference.trim() : null,
    });

    if (orderError || !data) {
      setError(orderError?.message || 'We could not place your order right now. Please try again.');
      setSubmitting(false);
      return;
    }
    onPlaced({ id: data as string, method, total: quote.total });
  };

  return <div className="sf-overlay sf-overlay-full"><div className="sf-checkout" role="dialog" aria-modal="true" aria-label="Checkout"><div className="sf-checkout-head"><div><h2 className="sf-h2">Checkout</h2></div><button className="sf-close sf-close-inline" aria-label="Close checkout" onClick={onClose}><X size={20}/></button></div><form onSubmit={submit}>
    <div className="sf-form-grid">
      <label>Full name<input name="name" required placeholder="Your name" defaultValue={customerName} /></label>
      <label>Email address<input type="email" name="email" required placeholder="you@example.com" defaultValue={customerSession?.user?.email || ''} /></label>
      <label>Phone number<input name="phone" required placeholder="+92 300 0000000" /></label>
      <label>Postal code<input name="postal" required placeholder="54000" /></label>
      <label className="sf-wide">Delivery address<input key={mapAddress} name="address" required placeholder="House number, street, area" defaultValue={mapAddress} /></label>
      <label>City<input name="city" required list="rabbent-cities" autoComplete="off" placeholder="Start typing your city" value={city} onChange={(e)=>setCity(e.target.value)} /><datalist id="rabbent-cities">{cities.map((c)=><option key={c} value={c}/>)}</datalist></label>
      <label>Payment method<select value={method} onChange={(e)=>setMethod(e.target.value as 'Cash on Delivery'|'Easypaisa')}><option value="Cash on Delivery">Cash on Delivery</option>{easypaisaReady && <option value="Easypaisa">Easypaisa (pay to our number)</option>}</select></label>
    </div>
    {method === 'Easypaisa' && <div className="sf-pay-panel">
      <p>Send <strong>{quote ? money(quote.total) : 'your order total'}</strong> by Easypaisa to:</p>
      <p className="sf-pay-number">{EASYPAISA_NUMBER}</p>
      {EASYPAISA_ACCOUNT_NAME && <p className="sf-pay-name">Account name: {EASYPAISA_ACCOUNT_NAME}</p>}
      <label>Transaction ID from your Easypaisa receipt<input required minLength={6} value={reference} onChange={(e)=>setReference(e.target.value)} placeholder="e.g. 12345678901" /></label>
      <small>We confirm your order once we have checked the payment.</small>
    </div>}
    <LocationPicker onPick={(p)=>{setPin(p);setMapAddress(p.address);}} />
    <div className="sf-coupon"><input value={coupon} onChange={(e)=>setCoupon(e.target.value)} placeholder="Coupon code" /><button type="button" className="sf-btn sf-btn-ghost" onClick={()=>void applyCoupon()}>Apply</button></div>
    <div className="sf-pay-summary">
      <div><span>Subtotal</span><strong>{quote ? money(quote.subtotal) : '—'}</strong></div>
      {quote && quote.discount > 0 && <div><span>Discount</span><strong>− {money(quote.discount)}</strong></div>}
      <div><span>Delivery</span><strong>{quote ? money(quote.delivery_fee) : 'Enter your city'}</strong></div>
    </div>
    <div className="sf-checkout-total"><span>Order total</span><strong>{quote ? money(quote.total) : '—'}</strong></div>
    {quoteError && <p className="sf-error">{quoteError}</p>}
    {error && <p className="sf-error">{error}</p>}
    <button className="sf-btn sf-btn-primary sf-btn-block" disabled={submitting || !quote}>{submitting ? 'Placing order...' : 'Place order'}</button>
  </form></div></div>;
}
