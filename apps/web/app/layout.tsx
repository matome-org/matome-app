import type { Metadata } from 'next';
import { cssVariables } from '@matome/ui';
import './globals.css';

export const metadata: Metadata = {
  title: 'Matome Web',
  description: 'Web shell for Matome recordings.',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <head>
        <style dangerouslySetInnerHTML={{ __html: cssVariables }} />
      </head>
      <body>{children}</body>
    </html>
  );
}
