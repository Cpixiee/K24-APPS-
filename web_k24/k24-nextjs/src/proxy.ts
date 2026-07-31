import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

// Route protection: redirects unauthenticated users to /login
// Uses a lightweight cookie "k24_auth" that we set on login
export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl
  const authIndicator = request.cookies.get('k24_auth')

  if (!authIndicator && pathname.startsWith('/dashboard')) {
    const loginUrl = new URL('/login', request.url)
    return NextResponse.redirect(loginUrl)
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/dashboard/:path*'],
}
