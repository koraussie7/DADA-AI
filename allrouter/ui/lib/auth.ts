import crypto from "crypto";

export interface SessionPayload {
  user_id: string;
  user_email: string | null;
  user_role: string | null;
  key: string;
}

const MASTER_KEY = process.env.LITELLM_MASTER_KEY || "";

export function signJwt(payload: SessionPayload): string {
  const header = { alg: "HS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const body = { ...payload, exp: now + 60 * 60 * 24 };
  const enc = (obj: object) =>
    Buffer.from(JSON.stringify(obj)).toString("base64url");
  const data = `${enc(header)}.${enc(body)}`;
  const sig = crypto
    .createHmac("sha256", MASTER_KEY)
    .update(data)
    .digest("base64url");
  return `${data}.${sig}`;
}

export function verifyJwt(token: string): SessionPayload | null {
  try {
    const [h, p, s] = token.split(".");
    if (!h || !p || !s) return null;
    const expected = crypto
      .createHmac("sha256", MASTER_KEY)
      .update(`${h}.${p}`)
      .digest("base64url");
    if (expected !== s) return null;
    const body = JSON.parse(Buffer.from(p, "base64url").toString("utf-8"));
    if (body.exp && body.exp * 1000 < Date.now()) return null;
    return {
      user_id: body.user_id,
      user_email: body.user_email ?? null,
      user_role: body.user_role ?? null,
      key: body.key ?? "",
    };
  } catch {
    return null;
  }
}

export function getSessionCookie(req: Request): string | null {
  const cookie = req.headers.get("cookie");
  if (!cookie) return null;
  const match = cookie
    .split(";")
    .map((c) => c.trim())
    .find((c) => c.startsWith("ar_session="));
  return match ? match.slice("ar_session=".length) : null;
}
