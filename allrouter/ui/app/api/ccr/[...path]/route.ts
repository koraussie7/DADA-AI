import { NextRequest, NextResponse } from "next/server";
import { createHash } from "crypto";
import { readFileSync } from "fs";

const CCR_BASE = process.env.CCR_BASE_URL || "http://127.0.0.1:20128";
const CCR_DATA_DIR = process.env.CCR_DATA_DIR || "/root/.9router";
const CLI_TOKEN_SALT = "9r-cli-auth";
const CLI_TOKEN_HEADER = "x-9r-cli-token";

function getCliToken(): string {
  const machineId = readFileSync(`${CCR_DATA_DIR}/machine-id`, "utf8").trim();
  const cliSecret = readFileSync(`${CCR_DATA_DIR}/auth/cli-secret`, "utf8").trim();
  return createHash("sha256")
    .update(machineId + CLI_TOKEN_SALT + cliSecret)
    .digest("hex")
    .substring(0, 16);
}

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
    [CLI_TOKEN_HEADER]: getCliToken(),
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
