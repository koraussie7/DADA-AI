import { NextRequest, NextResponse } from "next/server";

const CCR_BASE = process.env.CCR_BASE_URL || "http://127.0.0.1:20128";
const CCR_MANAGE_KEY =
  process.env.CCR_MANAGE_KEY || "om-prod-manage-9f2c1d7e8b0a4c5f";

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  return proxy(req, params, "GET");
}

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  return proxy(req, params, "POST");
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  return proxy(req, params, "DELETE");
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  return proxy(req, params, "PATCH");
}

async function proxy(
  req: NextRequest,
  params: Promise<{ path: string[] }>,
  method: string
) {
  const { path } = await params;
  const query = req.nextUrl.search;
  const url = `${CCR_BASE}/api/${path.join("/")}${query}`;

  let body: ArrayBuffer | null = null;
  if (method !== "GET" && method !== "DELETE") {
    body = await req.arrayBuffer();
  }

  const headers: Record<string, string> = {
    Authorization: `Bearer ${CCR_MANAGE_KEY}`,
  };
  if (body && body.byteLength > 0) {
    headers["Content-Type"] = "application/json";
  }

  try {
    const upstream = await fetch(url, {
      method,
      headers,
      body: body && body.byteLength > 0 ? body : undefined,
    });
    const text = await upstream.text();
    return new NextResponse(text, {
      status: upstream.status,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return NextResponse.json(
      {
        error: {
          message:
            err instanceof Error
              ? `CCR proxy error: ${err.message}`
              : "CCR proxy error",
        },
      },
      { status: 502 }
    );
  }
}
