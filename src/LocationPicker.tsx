import { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Free map: OpenStreetMap tiles + Nominatim search. No API key or billing needed.
export type Pin = { lat: number; lng: number; address: string };

export default function LocationPicker({ onPick }: { onPick: (p: Pin) => void }) {
  const el = useRef<HTMLDivElement>(null);
  const map = useRef<L.Map | null>(null);
  const marker = useRef<L.Marker | null>(null);
  const [q, setQ] = useState('');
  const [msg, setMsg] = useState('Search an address or click the map to drop a pin.');

  const place = async (lat: number, lng: number, label?: string) => {
    if (!map.current) return;
    if (marker.current) marker.current.setLatLng([lat, lng]);
    else marker.current = L.marker([lat, lng], { icon: L.divIcon({ className: '', html: '<div style="width:18px;height:18px;border-radius:50%;background:#111;border:3px solid #fff;box-shadow:0 0 0 1px #111"></div>', iconSize: [18, 18] }) }).addTo(map.current);
    map.current.setView([lat, lng], 15);
    let address = label || `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
    if (!label) {
      try {
        const r = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}`);
        address = (await r.json()).display_name || address;
      } catch { /* keep coordinates */ }
    }
    setMsg(address);
    onPick({ lat, lng, address });
  };

  useEffect(() => {
    if (!el.current || map.current) return;
    map.current = L.map(el.current).setView([33.6844, 73.0479], 11);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap' }).addTo(map.current);
    map.current.on('click', (e) => void place(e.latlng.lat, e.latlng.lng));
    return () => { map.current?.remove(); map.current = null; marker.current = null; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const search = async () => {
    if (!q.trim()) return;
    try {
      const r = await fetch(`https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=pk&q=${encodeURIComponent(q)}`);
      const [hit] = await r.json();
      if (hit) void place(Number(hit.lat), Number(hit.lon), hit.display_name);
      else setMsg('No match found. Try clicking the map instead.');
    } catch { setMsg('Search failed. Click the map to drop a pin.'); }
  };

  return <div style={{ marginBottom: 16 }}>
    <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
      <input value={q} onChange={(e) => setQ(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); void search(); } }} placeholder="Search your area (e.g. F-10 Islamabad)" style={{ flex: 1 }} />
      <button type="button" className="button button-outline" onClick={() => void search()}>Find</button>
    </div>
    <div ref={el} style={{ height: 240, borderRadius: 8, zIndex: 0 }} />
    <small style={{ display: 'block', marginTop: 6 }}>{msg}</small>
  </div>;
}
