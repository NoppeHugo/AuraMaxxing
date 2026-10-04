import type { Metadata, Viewport } from "next";
import { Nav } from "@/components/Nav";
import "./globals.css";

export const metadata: Metadata = {
  title: "AuraMaxxing — Battle d'aura",
  description: "Fais analyser ton aura par l'IA, affronte tes potes en battle et grimpe au classement.",
};

export const viewport: Viewport = { themeColor: "#07060d", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <body>
        <Nav />
        <main className="container">{children}</main>
      </body>
    </html>
  );
}
