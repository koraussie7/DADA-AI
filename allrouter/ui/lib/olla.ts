export async function ollaFetch(path: string, options?: RequestInit) {
  const res = await fetch(`/api/olla/${path}`, options);
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    const detail =
      data?.error?.message ||
      (typeof data?.error === "string" ? data.error : null);
    throw new Error(detail || `Olla 요청 실패 (${res.status})`);
  }
  return data;
}
