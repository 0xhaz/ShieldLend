import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'ShieldLend — Privacy-Native BTC Lending',
  description: 'Private BTC lending protocol on Starknet. Deposit, borrow, and earn yield with ZK-powered privacy.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
