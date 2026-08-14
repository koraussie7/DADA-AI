"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { Loader2 } from "lucide-react";

interface AuthCardProps {
  mode: "login" | "signup";
}

export default function AuthCard({ mode }: AuthCardProps) {
  const router = useRouter();
  const isLogin = mode === "login";
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [apiKey, setApiKey] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setApiKey(null);

    if (isLogin) {
      if (!email || !password) {
        setError("이메일과 비밀번호를 입력하세요.");
        return;
      }
    } else {
      if (password !== confirm) {
        setError("비밀번호가 일치하지 않습니다.");
        return;
      }
    }

    setLoading(true);
    try {
      const res = await fetch(`/api/auth/${mode}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(
          isLogin
            ? { username: email, password }
            : { email, password }
        ),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data?.error?.message || "요청 처리에 실패했습니다.");
      }
      if (isLogin) {
        router.push("/dashboard");
        router.refresh();
      } else {
        setApiKey(data.key || null);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "요청 처리에 실패했습니다.");
    } finally {
      setLoading(false);
    }
  };

  if (!isLogin && apiKey) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[var(--background)] px-4 text-[var(--foreground)]">
        <div className="w-full max-w-md rounded-2xl border border-[var(--border)] bg-[var(--panel)] p-8 animate-fade-up">
          <div className="mb-6 text-center">
            <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-[var(--accent)]/10 text-2xl">
              ✅
            </div>
            <h1 className="text-xl font-bold">가입 완료</h1>
            <p className="mt-2 text-sm text-[var(--muted)]">
              아래 API 키를 안전한 곳에 보관하세요. 다시 볼 수 없습니다.
            </p>
          </div>
          <div className="rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] p-4">
            <code className="block break-all font-mono text-sm text-[var(--accent)]">
              {apiKey}
            </code>
          </div>
          <button
            onClick={() => navigator.clipboard.writeText(apiKey)}
            className="mt-4 w-full rounded-lg border border-[var(--border-light)] py-2.5 text-sm font-medium transition-colors hover:border-[var(--muted)]"
          >
            키 복사
          </button>
          <button
            onClick={() => {
              router.push("/dashboard");
              router.refresh();
            }}
            className="mt-3 w-full rounded-lg bg-[var(--accent)] py-3 font-semibold text-white transition-all hover:bg-[var(--accent-hover)]"
          >
            대시보드로 이동
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--background)] px-4 text-[var(--foreground)]">
      <div className="w-full max-w-md">
        <div className="mb-8 text-center">
          <Link href="/" className="inline-flex items-center gap-2">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--accent)] text-lg font-bold text-white">
              AR
            </div>
            <span className="text-xl font-bold">AllRouter</span>
          </Link>
        </div>

        <div className="rounded-2xl border border-[var(--border)] bg-[var(--panel)] p-8 animate-fade-up">
          <h1 className="text-2xl font-bold tracking-tight">
            {isLogin ? "로그인" : "회원가입"}
          </h1>
          <p className="mt-2 text-sm text-[var(--muted)]">
            {isLogin
              ? "대시보드에 접속하세요."
              : "계정을 만들고 AI 게이트웨이를 사용하세요."}
          </p>

          <form onSubmit={handleSubmit} className="mt-8 space-y-4">
            <div>
              <label className="mb-1.5 block text-sm text-[var(--muted)]">
                {isLogin ? "이메일" : "이메일"}
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                className="w-full rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-4 py-2.5 text-sm outline-none transition-colors focus:border-[var(--accent)]"
              />
            </div>
            <div>
              <label className="mb-1.5 block text-sm text-[var(--muted)]">
                비밀번호
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-4 py-2.5 text-sm outline-none transition-colors focus:border-[var(--accent)]"
              />
            </div>
            {!isLogin && (
              <div>
                <label className="mb-1.5 block text-sm text-[var(--muted)]">
                  비밀번호 확인
                </label>
                <input
                  type="password"
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  placeholder="••••••••"
                  className="w-full rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-4 py-2.5 text-sm outline-none transition-colors focus:border-[var(--accent)]"
                />
              </div>
            )}

            {error && (
              <div className="rounded-lg border border-[#f85149]/30 bg-[#f85149]/10 p-3 text-sm text-[#f85149]">
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="flex w-full items-center justify-center gap-2 rounded-lg bg-[var(--accent)] py-3 font-semibold text-white transition-all hover:bg-[var(--accent-hover)] disabled:cursor-not-allowed disabled:opacity-60"
            >
              {loading && <Loader2 size={16} className="animate-spin" />}
              {isLogin ? "로그인" : "가입하기"}
            </button>
          </form>

          <p className="mt-6 text-center text-sm text-[var(--muted)]">
            {isLogin ? (
              <>
                계정이 없으신가요?{" "}
                <Link
                  href="/signup"
                  className="font-medium text-[var(--accent)] transition-colors hover:text-[var(--accent-hover)]"
                >
                  회원가입
                </Link>
              </>
            ) : (
              <>
                이미 계정이 있으신가요?{" "}
                <Link
                  href="/login"
                  className="font-medium text-[var(--accent)] transition-colors hover:text-[var(--accent-hover)]"
                >
                  로그인
                </Link>
              </>
            )}
          </p>
        </div>
      </div>
    </div>
  );
}
