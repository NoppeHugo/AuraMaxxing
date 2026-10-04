import { ImageResponse } from "next/og";
import { challengeInfo } from "@/lib/league/store";
import { displayFont } from "@/lib/ogFont";

export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const alt = "Défi d'aura AuraMaxxing";

/** Aperçu du lien dans Snap / iMessage / Insta : c'est lui qui donne envie de cliquer. */
export default async function Image({ params }: { params: Promise<{ code: string }> }) {
  const c = await challengeInfo((await params).code);
  const font = await displayFont();
  const c1 = c?.auraColor ?? "#b46bff";
  const c2 = c?.auraColor2 ?? "#3de8ff";
  // Même direction artistique que l'app : aplats, disque plein, typo condensée, pas de dégradé.
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          background: "#07060d",
          color: "white",
          position: "relative",
          fontFamily: font ? "Barlow Condensed" : undefined,
        }}
      >
        <div style={{ position: "absolute", width: 620, height: 620, borderRadius: 9999, background: c1, right: -170, top: -230 }} />
        <div style={{ position: "absolute", width: 720, height: 720, borderRadius: 9999, border: `4px solid ${c2}`, right: -230, top: -270 }} />
        <div style={{ display: "flex", flexDirection: "column", justifyContent: "center", padding: "0 80px", width: "100%" }}>
          <div style={{ fontSize: 34, fontWeight: 800, letterSpacing: 4, color: "#9c98b4" }}>DÉFI D'AURA</div>
          <div style={{ fontSize: 64, fontWeight: 900, marginTop: 6 }}>{`@${c?.from?.pseudo ?? "AuraMaxxing"} T'A DÉFIÉ`}</div>
          <div style={{ fontSize: 230, fontWeight: 900, lineHeight: 1, letterSpacing: -6 }}>{String(c?.score ?? "???")}</div>
          <div style={{ width: 260, height: 16, background: c1, marginTop: 8 }} />
          <div style={{ display: "flex", marginTop: 26 }}>
            <div style={{ fontSize: 40, fontWeight: 900, background: "#ffd25e", color: "#0b0a12", padding: "6px 18px", borderRadius: 8 }}>
              T'AS PLUS D'AURA ? PROUVE-LE.
            </div>
          </div>
        </div>
      </div>
    ),
    { ...size, fonts: font ? [{ name: "Barlow Condensed", data: font, weight: 800, style: "normal" }] : undefined },
  );
}
