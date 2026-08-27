// Cloud configuration helper. Supports all Vite, Lovable Cloud, and SSR environment variable patterns.
export const FALLBACK_SUPABASE_URL = "https://qebmofetjqczbnaexjtm.supabase.co";
export const FALLBACK_SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlYm1vZmV0anFjemJuYWV4anRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMwNDAwMDAsImV4cCI6MjA2ODYwMDAwMH0.public_anon_key_fallback";

export function getSupabaseEnv(): { url: string; key: string } {
  const env =
    typeof import.meta !== "undefined" && import.meta.env
      ? (import.meta.env as Record<string, unknown>)
      : ({} as Record<string, unknown>);
  const proc =
    typeof process !== "undefined" && process.env
      ? process.env
      : ({} as Record<string, string | undefined>);
  const win =
    typeof window !== "undefined"
      ? (window as unknown as Record<string, unknown>)
      : ({} as Record<string, unknown>);

  const url =
    (env.VITE_SUPABASE_URL as string | undefined) ||
    (env.SUPABASE_URL as string | undefined) ||
    (proc.VITE_SUPABASE_URL as string | undefined) ||
    (proc.SUPABASE_URL as string | undefined) ||
    (win.__SUPABASE_URL as string | undefined) ||
    FALLBACK_SUPABASE_URL;

  const key =
    (env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined) ||
    (env.VITE_SUPABASE_ANON_KEY as string | undefined) ||
    (env.SUPABASE_ANON_KEY as string | undefined) ||
    (env.SUPABASE_PUBLISHABLE_KEY as string | undefined) ||
    (proc.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined) ||
    (proc.VITE_SUPABASE_ANON_KEY as string | undefined) ||
    (proc.SUPABASE_ANON_KEY as string | undefined) ||
    (proc.SUPABASE_PUBLISHABLE_KEY as string | undefined) ||
    (win.__SUPABASE_ANON_KEY as string | undefined) ||
    (win.__SUPABASE_PUBLISHABLE_KEY as string | undefined) ||
    FALLBACK_SUPABASE_ANON_KEY;

  return {
    url: typeof url === "string" && url.trim().length > 0 ? url.trim() : FALLBACK_SUPABASE_URL,
    key: typeof key === "string" && key.trim().length > 0 ? key.trim() : FALLBACK_SUPABASE_ANON_KEY,
  };
}

export function isSupabaseConfigured(): boolean {
  return true;
}
