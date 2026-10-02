import { useState } from 'react';
import { ArrowRight, Lock, Mail, User, X } from 'lucide-react';
import { supabase } from '@/lib/supabase';

export default function CustomerAuth({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError('');

    if (mode === 'register') {
      const { data, error: authError } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { full_name: name } },
      });
      if (authError) {
        setError(authError.message);
        setSubmitting(false);
        return;
      }
      if (data.user) {
        onSuccess();
        return;
      }
      setError('Could not create account. Please try again.');
      setSubmitting(false);
    } else {
      const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
      if (authError) {
        setError(authError.message === 'Invalid login credentials'
          ? 'Incorrect email or password. Please try again.'
          : authError.message);
        setSubmitting(false);
        return;
      }
      onSuccess();
    }
  };

  return (
    <div className="modal-backdrop" onMouseDown={onClose}>
      <div className="admin-login-card" onMouseDown={(e) => e.stopPropagation()}>
        <button className="close-button" onClick={onClose}><X size={20} /></button>
        <div className="admin-login-hero">
          <span className="admin-logo">RABBENT<span>.</span></span>
          <p className="admin-sublabel">{mode === 'login' ? 'Welcome back' : 'Create account'}</p>
        </div>
        <div className="admin-login-body">
          <h2>{mode === 'login' ? 'Sign in' : 'Create your account'}</h2>
          <p className="admin-login-hint">
            {mode === 'login'
              ? 'Sign in to track your orders and checkout faster.'
              : 'Create an account to track your orders and save your details.'}
          </p>
          <form onSubmit={submit}>
            {mode === 'register' && (
              <label className="admin-field">
                <User size={16} />
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Your full name"
                  required
                />
              </label>
            )}
            <label className="admin-field">
              <Mail size={16} />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
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
                autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
                minLength={6}
              />
            </label>
            {error && <p className="form-error">{error}</p>}
            <button className="button button-dark full-button" disabled={submitting}>
              {submitting ? 'Please wait...' : mode === 'login' ? 'Sign in' : 'Create account'} <ArrowRight size={16} />
            </button>
          </form>
          <p className="admin-login-switch">
            {mode === 'login' ? (
              <>New to Rabbent? <button onClick={() => { setMode('register'); setError(''); }}>Create an account</button></>
            ) : (
              <>Already have an account? <button onClick={() => { setMode('login'); setError(''); }}>Sign in</button></>
            )}
          </p>
        </div>
      </div>
    </div>
  );
}
