import { ImageResponse } from "next/og";
import { challengeInfo } from "@/lib/league/store";

export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const alt = "Défi d'aura AuraMaxxing";

/** Aperçu du lien dans Snap / iMessage / Insta : c'est lui qui donne envie de cliquer. */
export default async function Image({ params }: { params: Promise<{ code: string }> }) {
  const c = await challengeInfo((await params).code);
  const c1 = c?.auraColor ?? "#b46bff";
  const c2 = c?.auraColor2 ?? "#3de8ff";
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          background: `radial-gradient(circle at 25% 30%, ${c1}66, transparent 55%), radial-gradient(circle at 80% 70%, ${c2}55, transparent 55%), #07060d`,
          color: "white",
          fontFamily: "sans-serif",
        }}
      >
        <div style={{ fontSize: 34, letterSpacing: 6, color: "#a39fbd" }}>DÉFI D'AURA</div>
        <div style={{ fontSize: 56, fontWeight: 800, marginTop: 10 }}>{`@${c?.from?.pseudo ?? "AuraMaxxing"} t'a défié`}</div>
        <div
          style={{
            fontSize: 200,
            fontWeight: 900,
            lineHeight: 1,
            marginTop: 10,
            backgroundImage: `linear-gradient(90deg, ${c1}, #ffffff, ${c2})`,
            backgroundClip: "text",
            color: "transparent",
          }}
        >
          {String(c?.score ?? "???")}
        </div>
        <div style={{ fontSize: 40, fontWeight: 700, marginTop: 16 }}>T'as plus d'aura ? Prouve-le.</div>
      </div>
    ),
    size,
  );
}
