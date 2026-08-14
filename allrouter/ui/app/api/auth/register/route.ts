import { NextRequest, NextResponse } from "next/server";

const LITELLM_BASE = process.env.LITELLM_BASE_URL || "http://127.0.0.1:4001";
const LITELLM_MASTER_KEY = process.env.LITELLM_MASTER_KEY || "";

export async function POST(req: NextRequest) {
  try {
    const { email, password } = await req.json();
    const username = String(email || "").trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(username)) {
      return NextResponse.json(
        { error: { message: "올바른 이메일 주소를 입력하세요." } },
        { status: 400 }
      );
    }
    if (!password || String(password).length < 8) {
      return NextResponse.json(
        { error: { message: "비밀번호는 8자 이상이어야 합니다." } },
        { status: 400 }
      );
    }

    const newUser = await fetch(`${LITELLM_BASE}/user/new`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${LITELLM_MASTER_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_email: username,
        auto_create_key: true,
        metadata: { source: "signup" },
      }),
    });
    const newUserData = await newUser.json();
    if (!newUser.ok || !newUserData.user_id) {
      return NextResponse.json(
        {
          error: {
            message:
              newUserData?.error?.message ||
              "계정 생성에 실패했습니다. 이미 가입된 이메일일 수 있습니다.",
          },
        },
        { status: newUser.status || 400 }
      );
    }

    const setPw = await fetch(`${LITELLM_BASE}/user/update`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${LITELLM_MASTER_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_id: newUserData.user_id,
        password: String(password),
      }),
    });
    const setPwData = await setPw.json();
    if (!setPw.ok) {
      return NextResponse.json(
        {
          error: {
            message: setPwData?.error?.message || "비밀번호 설정에 실패했습니다.",
          },
        },
        { status: setPw.status || 400 }
      );
    }

    return NextResponse.json({
      user_id: newUserData.user_id,
      user_email: username,
      key: newUserData.key || null,
    });
  } catch (err) {
    return NextResponse.json(
      {
        error: {
          message: err instanceof Error ? err.message : "회원가입 처리 중 오류가 발생했습니다.",
        },
      },
      { status: 500 }
    );
  }
}
