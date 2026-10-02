export type Product = {
  id: string;
  name: string;
  slug: string;
  description: string;
  price: number;
  compare_at_price: number | null;
  image_url: string;
  sizes: string[];
  colors: string[];
  inventory: number;
  featured: boolean;
  category_id: string | null;
  is_active: boolean;
};

export type Category = {
  id: string;
  name: string;
  slug: string;
  display_order: number;
};

export type ProductImage = {
  id: string;
  product_id: string;
  image_url: string;
  display_order: number;
};

export type CartItem = Product & { quantity: number; size: string; color: string };

export type Order = {
  id: string;
  customer_name: string;
  email: string;
  phone: string;
  address: string;
  city: string;
  postal_code: string;
  payment_method: string;
  status: string;
  subtotal: number;
  delivery_fee: number;
  total: number;
  created_at: string;
  customer_id: string | null;
};

export type OrderItem = {
  id: string;
  order_id: string;
  product_id: string | null;
  product_name: string;
  size: string;
  color: string;
  quantity: number;
  unit_price: number;
};

export type AdminRole = 'super_admin' | 'inventory_manager' | 'order_manager';

export const ORDER_STATUSES = ['pending', 'confirmed', 'packed', 'shipped', 'delivered', 'cancelled'] as const;
export type OrderStatus = typeof ORDER_STATUSES[number];

export const STATUS_STYLES: Record<string, string> = {
  pending: 'status-pending',
  confirmed: 'status-confirmed',
  packed: 'status-packed',
  shipped: 'status-shipped',
  delivered: 'status-delivered',
  cancelled: 'status-cancelled',
};

export const money = (value: number) => `Rs. ${Number(value).toLocaleString('en-IN')}`;
export const formatDate = (iso: string) => new Date(iso).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
export const formatTime = (iso: string) => new Date(iso).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
