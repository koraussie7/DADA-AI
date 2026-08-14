"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  KeyRound,
  Activity,
  CreditCard,
  Cpu,
  Settings,
  ExternalLink,
} from "lucide-react";

const menuItems = [
  { name: "대시보드", icon: LayoutDashboard, href: "/dashboard" },
  { name: "API 키", icon: KeyRound, href: "/dashboard/keys" },
  { name: "요청 로그", icon: Activity, href: "/dashboard/logs" },
  { name: "과금", icon: CreditCard, href: "/dashboard/billing" },
  { name: "모델", icon: Cpu, href: "/dashboard/models" },
  { name: "설정", icon: Settings, href: "/dashboard/settings" },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex h-screen w-64 shrink-0 flex-col border-r border-[var(--border)] bg-[var(--panel-2)]">
      <div className="flex items-center gap-2 p-6">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-[var(--accent)] text-sm font-bold text-white">
          AR
        </div>
        <div>
          <span className="block text-lg font-bold leading-tight">AllRouter</span>
          <span className="block text-[10px] text-[var(--muted)]">
            AI 게이트웨이
          </span>
        </div>
      </div>

      <nav className="flex-1 space-y-1 px-3">
        {menuItems.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.name}
              href={item.href}
              className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                active
                  ? "bg-[var(--accent)]/10 text-[var(--accent)]"
                  : "text-[var(--muted)] hover:bg-[var(--panel)] hover:text-white"
              }`}
            >
              <item.icon size={18} />
              {item.name}
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-[var(--border)] p-4">
        <div className="mb-4 rounded-lg border border-[var(--border)] bg-[var(--panel)] p-3">
          <p className="text-xs font-medium">잔액</p>
          <p className="mt-1 text-xl font-bold text-[var(--foreground)]">
            $12.50
          </p>
          <Link
            href="/dashboard/billing"
            className="mt-2 inline-flex items-center gap-1 text-xs text-[var(--accent)] transition-colors hover:text-[var(--accent-hover)]"
          >
            크레딧 충전 <ExternalLink size={12} />
          </Link>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-[var(--accent)] text-sm font-semibold text-white">
            U
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium">사용자</p>
            <p className="truncate text-xs text-[var(--muted)]">
              user@privseai.com
            </p>
          </div>
        </div>
      </div>
    </aside>
  );
}
