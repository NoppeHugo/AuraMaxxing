"use client";

import { useEffect, useRef } from "react";

/** Particules d'aura qui montent autour du contenu, aux couleurs de l'aura détectée. */
export function AuraField({ colors, intensity = 1 }: { colors: string[]; intensity?: number }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current!;
    const ctx = canvas.getContext("2d")!;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let raf = 0;
    const dpr = Math.min(2, window.devicePixelRatio || 1);

    const resize = () => {
      canvas.width = canvas.clientWidth * dpr;
      canvas.height = canvas.clientHeight * dpr;
    };
    resize();
    window.addEventListener("resize", resize);

    const count = Math.round(70 * intensity);
    const spawn = () => {
      const angle = Math.random() * Math.PI * 2;
      const radius = 0.22 + Math.random() * 0.2;
      return {
        x: 0.5 + Math.cos(angle) * radius,
        y: 0.5 + Math.sin(angle) * radius * 1.2,
        vy: -(0.0008 + Math.random() * 0.0025) * intensity,
        vx: (Math.random() - 0.5) * 0.0008,
        size: 1 + Math.random() * 3.5,
        life: 0,
        max: 80 + Math.random() * 140,
        color: colors[Math.floor(Math.random() * colors.length)],
      };
    };
    const particles = Array.from({ length: count }, () => ({ ...spawn(), life: Math.random() * 100 }));

    const draw = () => {
      const { width: w, height: h } = canvas;
      ctx.clearRect(0, 0, w, h);
      ctx.globalCompositeOperation = "lighter";
      for (const p of particles) {
        p.life += 1;
        p.x += p.vx;
        p.y += p.vy;
        if (p.life > p.max) Object.assign(p, spawn());
        const alpha = Math.sin((p.life / p.max) * Math.PI);
        const r = p.size * dpr;
        const g = ctx.createRadialGradient(p.x * w, p.y * h, 0, p.x * w, p.y * h, r * 4);
        g.addColorStop(0, p.color);
        g.addColorStop(1, "transparent");
        ctx.globalAlpha = alpha * 0.9;
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(p.x * w, p.y * h, r * 4, 0, Math.PI * 2);
        ctx.fill();
      }
      if (!reduced) raf = requestAnimationFrame(draw);
    };
    draw();

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
    };
  }, [colors, intensity]);

  return <canvas ref={ref} className="aura-canvas" aria-hidden />;
}
