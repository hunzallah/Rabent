import { useCallback, useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';

export type Field = { key: string; label: string; type?: 'text' | 'product' | 'number' | 'checkbox' | 'datetime-local'; required?: boolean; optional?: boolean };
type Row = Record<string, unknown> & { id: string };

// One reusable admin Create/Read/Update/Delete screen for a table.
export default function CrudPanel({ table, fields, readOnlyCreate = false, onToast }: { table: string; fields: Field[]; readOnlyCreate?: boolean; onToast: (m: string) => void }) {
  const [rows, setRows] = useState<Row[]>([]);
  const [form, setForm] = useState<Record<string, unknown>>({});
  const [editId, setEditId] = useState<string | null>(null);
  const [products, setProducts] = useState<{ id: string; name: string }[]>([]);
  useEffect(() => { if (fields.some((f) => f.type === 'product')) void supabase.from('products').select('id,name').order('name').then(({ data }) => setProducts(data || [])); }, [fields]);

  const load = useCallback(async () => {
    const { data } = await supabase.from(table).select('*').order('created_at', { ascending: false });
    setRows((data as Row[]) || []);
  }, [table]);
  useEffect(() => { void load(); setForm({}); setEditId(null); }, [load]);

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    const payload: Record<string, unknown> = {};
    fields.forEach((f) => { const v = form[f.key]; payload[f.key] = f.type === 'number' ? (f.optional && (v === '' || v === undefined || v === null) ? null : Number(v ?? 0)) : f.type === 'checkbox' ? Boolean(v) : v === '' || v === undefined ? null : v; });
    const { error } = editId ? await supabase.from(table).update(payload).eq('id', editId) : await supabase.from(table).insert(payload);
    if (error) { onToast(error.message); return; }
    onToast('Saved'); setForm({}); setEditId(null); void load();
  };
  const remove = async (id: string) => {
    if (!window.confirm('Delete this record?')) return;
    const { error } = await supabase.from(table).delete().eq('id', id);
    onToast(error ? error.message : 'Deleted'); void load();
  };

  return <div className="admin-card">
    {!readOnlyCreate && <form onSubmit={save} className="admin-form-grid" style={{ marginBottom: 16 }}>
      {fields.map((f) => <label key={f.key}>{f.label}
        {f.type === 'product'
          ? <select required value={String(form[f.key] ?? '')} onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}><option value="">Choose product</option>{products.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select>
          : f.type === 'checkbox'
          ? <input type="checkbox" checked={Boolean(form[f.key])} onChange={(e) => setForm({ ...form, [f.key]: e.target.checked })} />
          : <input type={f.type || 'text'} required={f.required} value={String(form[f.key] ?? '')} onChange={(e) => setForm({ ...form, [f.key]: e.target.value })} />}
      </label>)}
      <div className="admin-edit-actions"><button className="button button-dark">{editId ? 'Update' : 'Add'}</button>{editId && <button type="button" className="button button-outline" onClick={() => { setEditId(null); setForm({}); }}>Cancel</button>}</div>
    </form>}
    <table className="admin-table"><thead><tr>{fields.map((f) => <th key={f.key}>{f.label}</th>)}<th /></tr></thead>
      <tbody>{rows.length ? rows.map((r) => <tr key={r.id}>
        {fields.map((f) => <td key={f.key}>{f.type === 'product' ? (products.find((p) => p.id === r[f.key])?.name ?? '—') : f.type === 'checkbox' ? (r[f.key] ? 'Yes' : 'No') : String(r[f.key] ?? '—')}</td>)}
        <td>{!readOnlyCreate && <button className="button button-outline" onClick={() => { setEditId(r.id); setForm(r); }}>Edit</button>} <button className="button button-outline" onClick={() => void remove(r.id)}>Delete</button></td>
      </tr>) : <tr><td colSpan={fields.length + 1}><div className="admin-empty">Nothing here yet.</div></td></tr>}</tbody></table>
  </div>;
}
