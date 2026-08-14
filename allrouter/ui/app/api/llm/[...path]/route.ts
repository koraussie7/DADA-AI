import { NextRequest, NextResponse } from "next/server";

const LITELLM_BASE = process.env.LITELLM_BASE_URL || "http://127.0.0.1:4001";
const LITELLM_MASTER_KEY = process.env.LITELLM_MASTER_KEY || "";

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
  const url = `${LITELLM_BASE}/${path.join("/")}${query}`;

  let body: ArrayBuffer | null = null;
  if (method !== "GET" && method !== "DELETE") {
    body = await req.arrayBuffer();
  }

  const headers: Record<string, string> = {
    Authorization: `Bearer ${LITELLM_MASTER_KEY}`,
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
              ? `LiteLLM proxy error: ${err.message}`
              : "LiteLLM proxy error",
        },
      },
      { status: 502 }
    );
  }
}
