import type { Metadata, Viewport } from "next";
import { Barlow, Barlow_Condensed } from "next/font/google";
import { Nav } from "@/components/Nav";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.AURA_PUBLIC_URL ?? "http://localhost:3000"),
  title: "AuraMaxxing — Battle d'aura",
  description: "Fais analyser ton aura par l'IA, affronte tes potes en battle et grimpe au classement.",
};

// Typo condensée façon affiche / tableau de score, alignée sur l'app iOS (système « compressed »).
const display = Barlow_Condensed({ subsets: ["latin"], weight: ["700", "800", "900"], variable: "--font-display" });
const body = Barlow({ subsets: ["latin"], weight: ["400", "500", "600", "700"], variable: "--font-body" });

export const viewport: Viewport = { themeColor: "#07060d", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr" className={`${display.variable} ${body.variable}`}>
      <body>
        <Nav />
        <main className="container">{children}</main>
      </body>
    </html>
  );
}
