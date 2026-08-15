export async function ccrFetch(path: string, options?: RequestInit) {
  const res = await fetch(`/api/ccr/${path}`, options);
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(data?.error?.message || `CCR 요청 실패 (${res.status})`);
  }
  return data;
}
