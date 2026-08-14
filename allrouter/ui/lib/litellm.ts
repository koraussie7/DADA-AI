export async function llmFetch(path: string, options?: RequestInit) {
  const res = await fetch(`/api/llm/${path}`, options);
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(data?.error?.message || `LiteLLM 요청 실패 (${res.status})`);
  }
  return data;
}
