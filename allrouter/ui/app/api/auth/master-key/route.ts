import { NextRequest, NextResponse } from "next/server";
import { getSessionCookie, verifyJwt } from "@/lib/auth";

export async function GET(req: NextRequest) {
  const token = getSessionCookie(req);
  const session = token ? verifyJwt(token) : null;
  if (!session || session.user_role !== "proxy_admin") {
    return NextResponse.json(
      { error: { message: "관리자 권한이 필요합니다." } },
      { status: 403 }
    );
  }
  return NextResponse.json({
    master_key: process.env.LITELLM_MASTER_KEY || "",
  });
}
