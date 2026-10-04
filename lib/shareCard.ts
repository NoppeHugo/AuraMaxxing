"use client";

import { STAT_KEYS, STAT_LABELS, type AuraAnalysis } from "./schemas";

function loadImage(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = src;
  });
}

/** Génère une « carte d'aura » format story (1080×1920) prête à poster. */
export async function makeShareCard(photo: string, pseudo: string, a: AuraAnalysis): Promise<Blob> {
  const W = 1080;
  const H = 1920;
  const canvas = document.createElement("canvas");
  canvas.width = W;
  canvas.height = H;
  const ctx = canvas.getContext("2d")!;

  const bg = ctx.createLinearGradient(0, 0, W, H);
  bg.addColorStop(0, "#07060d");
  bg.addColorStop(0.5, "#120e22");
  bg.addColorStop(1, "#07060d");
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, W, H);

  for (const [x, y, c] of [
    [W * 0.2, 500, a.aura_color],
    [W * 0.8, 800, a.aura_color_2],
  ] as const) {
    const glow = ctx.createRadialGradient(x, y, 0, x, y, 700);
    glow.addColorStop(0, `${c}88`);
    glow.addColorStop(1, "transparent");
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, W, H);
  }

  // Photo avec halo
  const img = await loadImage(photo);
  const pw = 600;
  const ph = 800;
  const px = (W - pw) / 2;
  const py = 170;
  ctx.save();
  ctx.shadowColor = a.aura_color;
  ctx.shadowBlur = 120;
  ctx.fillStyle = a.aura_color;
  ctx.beginPath();
  ctx.roundRect(px - 8, py - 8, pw + 16, ph + 16, 48);
  ctx.fill();
  ctx.restore();
  ctx.save();
  ctx.beginPath();
  ctx.roundRect(px, py, pw, ph, 40);
  ctx.clip();
  const scale = Math.max(pw / img.width, ph / img.height);
  ctx.drawImage(img, px + (pw - img.width * scale) / 2, py + (ph - img.height * scale) / 2, img.width * scale, img.height * scale);
  ctx.restore();

  ctx.textAlign = "center";
  ctx.fillStyle = "#fff";
  ctx.font = "900 64px system-ui, sans-serif";
  ctx.fillText("AuraMaxxing", W / 2, 110);

  ctx.font = "700 44px system-ui, sans-serif";
  ctx.fillStyle = "#c9c4e6";
  ctx.fillText(`@${pseudo}`, W / 2, 1060);

  const scoreGrad = ctx.createLinearGradient(W / 2 - 250, 0, W / 2 + 250, 0);
  scoreGrad.addColorStop(0, a.aura_color);
  scoreGrad.addColorStop(1, a.aura_color_2);
  ctx.fillStyle = scoreGrad;
  ctx.font = "900 220px system-ui, sans-serif";
  ctx.fillText(String(a.aura_score), W / 2, 1270);

  ctx.fillStyle = "#fff";
  ctx.font = "900 54px system-ui, sans-serif";
  ctx.fillText(`${a.emoji} ${a.tier.toUpperCase()}`, W / 2, 1360);
  ctx.font = "italic 600 40px system-ui, sans-serif";
  ctx.fillStyle = "#c9c4e6";
  ctx.fillText(a.title, W / 2, 1425, W - 120);

  // Stats
  ctx.textAlign = "left";
  STAT_KEYS.forEach((k, i) => {
    const y = 1500 + i * 62;
    ctx.fillStyle = "#a39fbd";
    ctx.font = "700 32px system-ui, sans-serif";
    ctx.fillText(STAT_LABELS[k], 140, y + 22);
    ctx.fillStyle = "rgba(255,255,255,0.1)";
    ctx.beginPath();
    ctx.roundRect(400, y, 440, 20, 10);
    ctx.fill();
    ctx.fillStyle = scoreGrad;
    ctx.beginPath();
    ctx.roundRect(400, y, Math.max(20, 4.4 * a.stats[k]), 20, 10);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.fillText(String(a.stats[k]), 870, y + 22);
  });

  ctx.textAlign = "center";
  ctx.fillStyle = "#a39fbd";
  ctx.font = "600 32px system-ui, sans-serif";
  ctx.fillText(a.trends.map((t) => `#${t.name.replace(/[^\p{L}\p{N}]+/gu, "")}`).join("  "), W / 2, 1850, W - 120);

  return new Promise((resolve, reject) => canvas.toBlob((b) => (b ? resolve(b) : reject(new Error("toBlob"))), "image/png"));
}

export async function shareOrDownload(blob: Blob, filename: string) {
  const file = new File([blob], filename, { type: "image/png" });
  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: "Mon aura sur AuraMaxxing" });
      return;
    } catch (error) {
      if ((error as DOMException).name === "AbortError") return;
    }
  }
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
