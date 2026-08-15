import { NextRequest, NextResponse } from "next/server";

const OLLA_BASE = process.env.OLLA_BASE_URL || "http://127.0.0.1:40114";

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

async function proxy(
  req: NextRequest,
  params: Promise<{ path: string[] }>,
  method: string
) {
  const { path } = await params;
  const query = req.nextUrl.search;
  const url = `${OLLA_BASE}/${path.join("/")}${query}`;

  let body: ArrayBuffer | null = null;
  if (method !== "GET") {
    body = await req.arrayBuffer();
  }

  const headers: Record<string, string> = {};
  if (body && body.byteLength > 0) {
    headers["Content-Type"] = "application/json";
  }

  try {
    const upstream = await fetch(url, {
      method,
      headers,
      body: body && body.byteLength > 0 ? body : undefined,
    });
    const contentType = upstream.headers.get("content-type") || "";
    const text = await upstream.text();
    return new NextResponse(text, {
      status: upstream.status,
      headers: {
        "Content-Type": contentType.includes("text/event-stream")
          ? "text/event-stream"
          : contentType.includes("text/plain")
            ? "text/plain"
            : "application/json",
      },
    });
  } catch (err) {
    return NextResponse.json(
      {
        error: {
          message:
            err instanceof Error
              ? `Olla proxy error: ${err.message}`
              : "Olla proxy error",
        },
      },
      { status: 502 }
    );
  }
}
