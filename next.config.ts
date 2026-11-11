import type {NextConfig} from 'next';

// Prevent Next.js 15 worker crash when NODE_ENV is set to 'development' in build environments
if (process.env.NODE_ENV === 'development' && process.env.NEXT_PHASE !== 'phase-development-server') {
  delete process.env.NODE_ENV;
}

const nextConfig: NextConfig = {
  // Image optimization
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
        port: '',
        pathname: '/**',
      },
      {
        protocol: 'https',
        hostname: 'picsum.photos',
        port: '',
        pathname: '/**',
      },
      {
        protocol: 'https',
        hostname: 'i.pravatar.cc',
        port: '',
        pathname: '/**',
      },
      {
        protocol: 'https',
        hostname: '**.supabase.co',
        port: '',
        pathname: '/**',
      },
      {
        protocol: 'https',
        hostname: '**.cjdropshipping.com',
        port: '',
        pathname: '/**',
      },
    ],
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
  },

  // Performance & Build Resilience
  compress: true,
  productionBrowserSourceMaps: false,
  eslint: {
    ignoreDuringBuilds: true,
  },
  typescript: {
    ignoreBuildErrors: true,
  },
  allowedDevOrigins: [
    '*.run.app',
    'ais-dev-tiievmshg3sr4inuvxwl7p-647798679951.europe-west2.run.app',
    'ais-pre-tiievmshg3sr4inuvxwl7p-647798679951.europe-west2.run.app',
    'localhost:3000',
    '127.0.0.1:3000',
  ],

  // Redirects for old paths (if migrating from Firebase)
  async redirects() {
    return [
      // Add Firebase to Vercel redirects here if needed
    ]
  },

  // Security headers
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          // Removed X-Frame-Options: DENY to allow previewing the app within the AI Studio frame / iframe
          /*
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          */
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
          {
            key: 'Permissions-Policy',
            value: 'geolocation=(self), microphone=(), camera=()',
          },
        ],
      },
      {
        source: '/public/static/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
    ];
  },

  // Rewrites for API
  async rewrites() {
    return [];
  },
};

export default nextConfig;
