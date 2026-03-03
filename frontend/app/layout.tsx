import type { Metadata } from "next";
import "./globals.css";
import { StarknetProvider } from "@/lib/starknet-provider";
import { Header } from "@/components/layout/Header";
import { Toaster } from "@/components/shared/Toaster";

export const metadata: Metadata = {
  title: "ShieldLend — Privacy-Native BTC Lending",
  description:
    "Private BTC lending protocol on Starknet. Deposit, borrow, and earn yield with ZK-powered privacy.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen bg-gray-950 text-gray-100 antialiased">
        <StarknetProvider>
          <Header />
          <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            {children}
          </main>
          <Toaster />
        </StarknetProvider>
      </body>
    </html>
  );
}
