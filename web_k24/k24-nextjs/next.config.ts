import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  allowedDevOrigins: ["0.0.0.0", "localhost", "127.0.0.1", "192.168.18.228", "192.168.8.190"],
  turbopack: {
    root: __dirname,
  },
};

export default nextConfig;
