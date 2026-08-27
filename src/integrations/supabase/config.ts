// Cloud configuration helper. Supports all Vite, Lovable Cloud, and SSR environment variable patterns.
export function getSupabaseEnv(): { url: string | undefined; key: string | undefined } {
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
    undefined;

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
    undefined;

  return {
    url: typeof url === "string" && url.trim().length > 0 ? url.trim() : undefined,
    key: typeof key === "string" && key.trim().length > 0 ? key.trim() : undefined,
  };
}

export function isSupabaseConfigured(): boolean {
  const { url, key } = getSupabaseEnv();
  return Boolean(url && key);
}
