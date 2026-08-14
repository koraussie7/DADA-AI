import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "AllRouter - 모든 AI 모델을 하나의 API로",
  description:
    "AllRouter는 여러 AI 모델(GPT, Claude, Gemini, 오픈소스)을 하나의 OpenAI 호환 API로 통합하고, 스마트 라우팅과 실시간 비용 추적을 제공하는 AI 게이트웨이입니다.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="ko"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full">{children}</body>
    </html>
  );
}
