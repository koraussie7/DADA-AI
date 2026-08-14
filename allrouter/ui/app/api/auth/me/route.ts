import { NextRequest, NextResponse } from "next/server";
import { getSessionCookie, verifyJwt } from "@/lib/auth";

export async function GET(req: NextRequest) {
  const token = getSessionCookie(req);
  if (!token) {
    return NextResponse.json({ authenticated: false }, { status: 200 });
  }
  const session = verifyJwt(token);
  if (!session) {
    return NextResponse.json({ authenticated: false }, { status: 200 });
  }
  return NextResponse.json({
    authenticated: true,
    user: session,
    isAdmin: session.user_role === "proxy_admin",
  });
}
