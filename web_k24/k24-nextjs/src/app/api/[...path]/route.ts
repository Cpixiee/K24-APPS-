import { NextRequest, NextResponse } from 'next/server'

const BACKEND_URL = process.env.BACKEND_INTERNAL_URL || process.env.NEXT_PUBLIC_API_URL || 'http://backend:8087'

export async function GET(request: NextRequest, props: { params: Promise<{ path: string[] }> }) {
  const { path } = await props.params
  return handleProxy(request, path)
}

export async function POST(request: NextRequest, props: { params: Promise<{ path: string[] }> }) {
  const { path } = await props.params
  return handleProxy(request, path)
}

export async function PUT(request: NextRequest, props: { params: Promise<{ path: string[] }> }) {
  const { path } = await props.params
  return handleProxy(request, path)
}

export async function PATCH(request: NextRequest, props: { params: Promise<{ path: string[] }> }) {
  const { path } = await props.params
  return handleProxy(request, path)
}

export async function DELETE(request: NextRequest, props: { params: Promise<{ path: string[] }> }) {
  const { path } = await props.params
  return handleProxy(request, path)
}

async function handleProxy(request: NextRequest, pathSegments: string[]) {
  const path = pathSegments.join('/')
  const searchParams = request.nextUrl.searchParams.toString()
  const targetUrl = `${BACKEND_URL}/api/${path}${searchParams ? `?${searchParams}` : ''}`

  const headers = new Headers()
  request.headers.forEach((value, key) => {
    // Forward all headers except host to avoid proxy host mismatch
    if (key.toLowerCase() !== 'host') {
      headers.set(key, value)
    }
  })

  // Read request body for mutating methods
  let body: ArrayBuffer | undefined = undefined
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method)) {
    try {
      body = await request.arrayBuffer()
    } catch (_) {}
  }

  try {
    const res = await fetch(targetUrl, {
      method: request.method,
      headers,
      body,
      // For Node environment to allow body streams properly
      duplex: body ? 'half' : undefined,
    } as any)

    const responseHeaders = new Headers()
    res.headers.forEach((value, key) => {
      // Don't forward Content-Encoding (e.g. gzip) if we are sending plain arrayBuffer
      if (key.toLowerCase() !== 'content-encoding') {
        responseHeaders.set(key, value)
      }
    })

    const responseBody = await res.arrayBuffer()
    return new NextResponse(responseBody, {
      status: res.status,
      statusText: res.statusText,
      headers: responseHeaders,
    })
  } catch (error: any) {
    console.error(`[Proxy] ${request.method} /api/${path} → Error: ${error.message}`)
    return NextResponse.json(
      { status: 'error', message: `Backend tidak dapat dijangkau. Pastikan server berjalan.` },
      { status: 503 }
    )
  }
}
