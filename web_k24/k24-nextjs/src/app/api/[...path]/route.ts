import { NextRequest, NextResponse } from 'next/server'

const BACKEND_URL = process.env.BACKEND_INTERNAL_URL || 'http://backend:8087'

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
  const hopByHopHeaders = new Set([
    'host',
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
    'content-length',
    'accept-encoding',
  ])

  request.headers.forEach((value, key) => {
    if (!hopByHopHeaders.has(key.toLowerCase())) {
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
      signal: AbortSignal.timeout(10000),
      // For Node environment to allow body streams properly
      duplex: body ? 'half' : undefined,
    } as any)

    const responseHeaders = new Headers()
    res.headers.forEach((value, key) => {
      const lowerKey = key.toLowerCase()
      if (!hopByHopHeaders.has(lowerKey) && lowerKey !== 'content-encoding') {
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
