import { NextRequest, NextResponse } from "next/server";
import { signJwt } from "@/lib/auth";

const LITELLM_BASE = process.env.LITELLM_BASE_URL || "http://127.0.0.1:4001";

export async function POST(req: NextRequest) {
  try {
    const { username, password } = await req.json();
    if (!username || !password) {
      return NextResponse.json(
        { error: { message: "아이디와 비밀번호를 입력하세요." } },
        { status: 400 }
      );
    }

    const upstream = await fetch(`${LITELLM_BASE}/v2/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username, password }),
    });
    const data = await upstream.json();

    if (!upstream.ok || !data.token) {
      return NextResponse.json(
        {
          error: {
            message:
              data?.error?.message || "로그인에 실패했습니다. 자격 증명을 확인하세요.",
          },
        },
        { status: upstream.status || 401 }
      );
    }

    const payload = decodeToken(data.token);
    if (!payload) {
      return NextResponse.json(
        { error: { message: "로그인 응답을 처리하지 못했습니다." } },
        { status: 500 }
      );
    }

    const session = {
      user_id: payload.user_id ?? "default_user_id",
      user_email: payload.user_email ?? null,
      user_role: payload.user_role ?? null,
      key: payload.key ?? "",
    };

    const response = NextResponse.json({
      user: session,
      isAdmin: session.user_role === "proxy_admin",
    });
    response.cookies.set("ar_session", signJwt(session), {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      maxAge: 60 * 60 * 24,
      path: "/",
    });
    return response;
  } catch (err) {
    return NextResponse.json(
      {
        error: {
          message: err instanceof Error ? err.message : "로그인 처리 중 오류가 발생했습니다.",
        },
      },
      { status: 500 }
    );
  }
}

function decodeToken(token: string): {
  user_id?: string;
  user_email?: string;
  user_role?: string;
  key?: string;
} | null {
  try {
    const payload = token.split(".")[1];
    if (!payload) return null;
    return JSON.parse(Buffer.from(payload, "base64url").toString("utf-8"));
  } catch {
    return null;
  }
}
