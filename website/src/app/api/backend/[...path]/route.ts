import { NextRequest, NextResponse } from "next/server";

const backendBaseUrl =
  process.env.BACKEND_BASE_URL ?? "https://emadcrm.compassaccuracy.com/api";

function buildUrl(pathParts: string[], searchParams: URLSearchParams): string {
  const safePath = pathParts.map(encodeURIComponent).join("/");
  const base = backendBaseUrl.replace(/\/+$/, "");
  const query = searchParams.toString();
  return query ? `${base}/${safePath}?${query}` : `${base}/${safePath}`;
}

function normalizePathParts(pathParts: string[], method: string): string[] {
  // Backward compatibility: some clients call /users/me for the current profile.
  if (
    method === "GET" &&
    pathParts.length === 2 &&
    pathParts[0] === "users" &&
    pathParts[1] === "me"
  ) {
    return ["auth", "me"];
  }
  return pathParts;
}

async function proxy(request: NextRequest, pathParts: string[]): Promise<NextResponse> {
  const resolvedPath = normalizePathParts(pathParts, request.method);
  const headers = new Headers();
  const auth = request.headers.get("authorization");
  if (auth) headers.set("authorization", auth);
  const cookie = request.headers.get("cookie");
  if (cookie) headers.set("cookie", cookie);
  headers.set("accept", "application/json");

  const contentType = request.headers.get("content-type");
  if (contentType) headers.set("content-type", contentType);

  const init: RequestInit = {
    method: request.method,
    headers,
    cache: "no-store"
  };

  if (request.method !== "GET" && request.method !== "HEAD") {
    const contentTypeValue = contentType?.toLowerCase() ?? "";
    if (contentTypeValue.startsWith("multipart/form-data")) {
      init.body = await request.arrayBuffer();
    } else {
      init.body = await request.text();
    }
  }

  try {
    const response = await fetch(buildUrl(resolvedPath, request.nextUrl.searchParams), init);
    const body = await response.text();
    const responseHeaders = new Headers();
    const contentType = response.headers.get("content-type");
    if (contentType) responseHeaders.set("content-type", contentType);

    const getSetCookie = (
      response.headers as Headers & { getSetCookie?: () => string[] }
    ).getSetCookie;
    if (typeof getSetCookie === "function") {
      const cookies = getSetCookie.call(response.headers);
      for (const setCookie of cookies) {
        responseHeaders.append("set-cookie", setCookie);
      }
    } else {
      const setCookie = response.headers.get("set-cookie");
      if (setCookie) responseHeaders.set("set-cookie", setCookie);
    }

    return new NextResponse(body, {
      status: response.status,
      headers: responseHeaders
    });
  } catch {
    return NextResponse.json(
      { detail: "Unable to reach backend server" },
      { status: 502 }
    );
  }
}

export async function GET(
  request: NextRequest,
  context: { params: { path: string[] } }
): Promise<NextResponse> {
  return proxy(request, context.params.path);
}

export async function POST(
  request: NextRequest,
  context: { params: { path: string[] } }
): Promise<NextResponse> {
  return proxy(request, context.params.path);
}

export async function PATCH(
  request: NextRequest,
  context: { params: { path: string[] } }
): Promise<NextResponse> {
  return proxy(request, context.params.path);
}

export async function PUT(
  request: NextRequest,
  context: { params: { path: string[] } }
): Promise<NextResponse> {
  return proxy(request, context.params.path);
}

export async function DELETE(
  request: NextRequest,
  context: { params: { path: string[] } }
): Promise<NextResponse> {
  return proxy(request, context.params.path);
}
