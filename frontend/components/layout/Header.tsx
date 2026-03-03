"use client";

import Link from "next/link";
import { Shield } from "lucide-react";
import { WalletConnect } from "./WalletConnect";
import { ShieldToggle } from "../privacy/ShieldToggle";

const navLinks = [
  { href: "/markets", label: "Markets" },
  { href: "/lend", label: "Lend" },
  { href: "/borrow", label: "Borrow" },
  { href: "/yield", label: "Yield" },
  { href: "/portfolio", label: "Portfolio" },
];

export function Header() {
  return (
    <header className="border-b border-gray-800 bg-gray-950/80 backdrop-blur-sm sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-2">
            <Shield className="h-8 w-8 text-emerald-400" />
            <span className="text-xl font-bold text-white">ShieldLend</span>
          </Link>

          {/* Navigation */}
          <nav className="hidden md:flex items-center gap-1">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="px-3 py-2 text-sm font-medium text-gray-300 hover:text-white hover:bg-gray-800 rounded-lg transition-colors cursor-pointer"
              >
                {link.label}
              </Link>
            ))}
          </nav>

          {/* Right side: shield toggle + wallet */}
          <div className="flex items-center gap-3">
            <ShieldToggle />
            <WalletConnect />
          </div>
        </div>
      </div>
    </header>
  );
}
