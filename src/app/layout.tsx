import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Viateria — eToro Portfolio Cockpit",
  description:
    "A modern portfolio dashboard and social-trading cockpit powered by the eToro Public API.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="font-sans antialiased">{children}</body>
    </html>
  );
}
