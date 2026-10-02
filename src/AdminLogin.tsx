import { useState } from 'react';
import { ArrowRight, ArrowLeft, Lock, Mail, ShieldCheck, X } from 'lucide-react';
import { supabase } from '@/lib/supabase';

export default function AdminLogin({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError('');

    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({ email, password });

    if (authError) {
      setError(authError.message === 'Invalid login credentials'
        ? 'Incorrect email or password. Please try again.'
        : authError.message);
      setSubmitting(false);
      return;
    }

    if (authData.user) {
      const { data: roleData } = await supabase.rpc('admin_role').maybeSingle();
      if (!roleData) {
        await supabase.auth.signOut();
        setError('This account does not have admin access.');
        setSubmitting(false);
        return;
      }
    }

    onSuccess();
  };

  return (
    <div className="modal-backdrop" onMouseDown={onClose}>
      <div className="admin-login-card" onMouseDown={(e) => e.stopPropagation()}>
        <button className="close-button" onClick={onClose}><X size={20} /></button>
        <div className="admin-login-hero">
          <span className="admin-logo">RABBENT<span>.</span></span>
          <p className="admin-sublabel">Studio Console</p>
          <div className="admin-login-lock"><Lock size={28} /></div>
        </div>
        <div className="admin-login-body">
          <h2>Admin sign in</h2>
          <p className="admin-login-hint">
            This area is restricted. Enter your admin credentials to manage orders and products.
          </p>
          <form onSubmit={submit}>
            <label className="admin-field">
              <Mail size={16} />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@rabbent.com"
                required
                autoComplete="email"
              />
            </label>
            <label className="admin-field">
              <Lock size={16} />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Your password"
                required
                autoComplete="current-password"
              />
            </label>
            {error && <p className="form-error">{error}</p>}
            <button className="button button-dark full-button" disabled={submitting}>
              {submitting ? 'Please wait...' : 'Sign in'} <ArrowRight size={16} />
            </button>
          </form>
          <div className="admin-login-restricted">
            <ShieldCheck size={14} />
            <p>Only pre-authorized admin accounts can sign in. New sign-ups are disabled.</p>
          </div>
          <button className="admin-login-back" onClick={onClose}>
            <ArrowLeft size={14} /> Back to store
          </button>
        </div>
      </div>
    </div>
  );
}
