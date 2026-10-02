/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_ANON_KEY: string;
  readonly VITE_GOOGLE_MAPS_API_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

interface Window {
  google?: {
    maps?: {
      places?: {
        Autocomplete: new (input: HTMLInputElement, opts?: Record<string, unknown>) => {
          addListener: (event: string, handler: () => void) => void;
          getPlace: () => { formatted_address?: string };
        };
      };
    };
  };
}
