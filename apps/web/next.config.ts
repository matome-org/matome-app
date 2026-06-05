import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  transpilePackages: ['@matome/api-client', '@matome/ui'],
};

export default nextConfig;
