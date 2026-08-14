"use client";

import { CreditCard, Download } from "lucide-react";

const packages = [
  { amount: 10, label: "스타터", desc: "가볍게 시작하기 좋은 용량" },
  { amount: 50, label: "개발자", desc: "활발한 개발용 추천" },
  { amount: 100, label: "엔터프라이즈", desc: "대규모 트래픽용" },
];

const history = [
  { id: "INV-2026-0012", date: "2026-08-01", desc: "개발자 패키지 충전", amount: 50, status: "완료" },
  { id: "INV-2026-0011", date: "2026-07-15", desc: "스타터 패키지 충전", amount: 10, status: "완료" },
  { id: "INV-2026-0010", date: "2026-07-01", desc: "개발자 패키지 충전", amount: 50, status: "완료" },
  { id: "INV-2026-0009", date: "2026-06-20", desc: "스타터 패키지 충전", amount: 10, status: "환불" },
];

export default function BillingPage() {
  return (
    <div className="p-8">
      <header className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">과금 & 크레딧</h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          크레딧을 충전하고 결제 내역을 확인하세요.
        </p>
      </header>

      {/* 잔액 카드 */}
      <div className="mb-8 grid grid-cols-1 gap-6 md:grid-cols-3">
        <div className="rounded-xl border border-[var(--border)] bg-gradient-to-br from-[var(--accent)]/15 to-transparent p-6 md:col-span-2">
          <p className="text-sm text-[var(--muted)]">현재 잔액</p>
          <p className="mt-2 text-4xl font-bold">$12.50</p>
          <p className="mt-1 text-xs text-[var(--muted)]">
            이번 달 사용: $8.40 / 충전된 크레딧: $20.00
          </p>
          <div className="mt-4 h-2 w-full overflow-hidden rounded-full bg-[var(--panel-2)]">
            <div className="h-full w-[42%] rounded-full bg-[var(--accent)]" />
          </div>
        </div>
        <div className="flex flex-col justify-center rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
          <p className="text-sm text-[var(--muted)]">이번 달 총 지출</p>
          <p className="mt-2 text-4xl font-bold">$8.40</p>
          <p className="mt-1 text-xs text-[#3fb950]">
            예산 대비 42% 사용
          </p>
        </div>
      </div>

      {/* 크레딧 충전 */}
      <div className="mb-8">
        <h2 className="mb-4 text-lg font-semibold">크레딧 충전</h2>
        <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
          {packages.map((pkg) => (
            <div
              key={pkg.amount}
              className="flex flex-col rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6 text-center transition-all hover:-translate-y-1 hover:border-[var(--accent)]"
            >
              <h3 className="text-lg font-semibold">{pkg.label}</h3>
              <div className="mt-2 text-4xl font-bold">
                ${pkg.amount}
              </div>
              <p className="mt-2 mb-6 text-sm text-[var(--muted)]">{pkg.desc}</p>
              <button className="mt-auto flex w-full items-center justify-center gap-2 rounded-lg bg-[var(--accent)] py-2.5 font-medium text-white transition-all hover:bg-[var(--accent-hover)]">
                <CreditCard size={16} />
                충전하기
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* 결제 내역 */}
      <div className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--panel)]">
        <div className="flex items-center justify-between border-b border-[var(--border)] p-6">
          <h2 className="text-lg font-semibold">결제 내역</h2>
          <button className="flex items-center gap-2 text-sm text-[var(--accent)] transition-colors hover:text-[var(--accent-hover)]">
            <Download size={15} />
            CSV 다운로드
          </button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-[var(--panel-2)] text-[var(--muted)]">
              <tr>
                <th className="p-4 font-medium">영수증 ID</th>
                <th className="p-4 font-medium">날짜</th>
                <th className="p-4 font-medium">내용</th>
                <th className="p-4 font-medium">금액</th>
                <th className="p-4 font-medium">상태</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--border)]">
              {history.map((h) => (
                <tr key={h.id} className="transition-colors hover:bg-[var(--panel-2)]">
                  <td className="p-4 font-mono text-xs text-[var(--accent)]">
                    {h.id}
                  </td>
                  <td className="p-4 text-[var(--muted)]">{h.date}</td>
                  <td className="p-4">{h.desc}</td>
                  <td className="p-4 font-medium">${h.amount}.00</td>
                  <td className="p-4">
                    {h.status === "완료" ? (
                      <span className="rounded-full bg-[#3fb950]/10 px-2.5 py-1 text-xs text-[#3fb950]">
                        완료
                      </span>
                    ) : (
                      <span className="rounded-full bg-[#d29922]/10 px-2.5 py-1 text-xs text-[#d29922]">
                        환불
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
