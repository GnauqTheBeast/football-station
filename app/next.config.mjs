/** @type {import('next').NextConfig} */
const nextConfig = {
  // Server-only env (do NOT prefix with NEXT_PUBLIC_)
  experimental: {
    serverComponentsExternalPackages: ["pg"]
  }
};
export default nextConfig;
