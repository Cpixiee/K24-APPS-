import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  allowedDevOrigins: ["0.0.0.0", "localhost", "127.0.0.1", "192.168.18.228", "192.168.8.190"],
  turbopack: {
    root: __dirname,
  },
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8087'}/api/:path*`,
      },
    ]
  },
};

export default nextConfig;
