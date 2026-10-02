import { Component, StrictMode, type ReactNode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.tsx';
import './index.css';

class Boundary extends Component<{ children: ReactNode }, { err: Error | null }> {
  state = { err: null as Error | null };
  static getDerivedStateFromError(err: Error) { return { err }; }
  render() {
    return this.state.err
      ? <pre style={{ padding: 24, whiteSpace: 'pre-wrap', fontFamily: 'monospace' }}>Rabbent hit an error:{'\n\n'}{this.state.err.message}</pre>
      : this.props.children;
  }
}

createRoot(document.getElementById('root')!).render(<StrictMode><Boundary><App /></Boundary></StrictMode>);
