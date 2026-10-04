"use client";

import { useState } from "react";

/**
 * Sans outil de « deferred deep link », le code est perdu pendant l'installation.
 * On le copie donc dans le presse-papiers avant d'ouvrir l'App Store : l'app propose ensuite de le coller.
 */
export function GetAppButtons({ code, appStoreUrl, deepLink }: { code: string; appStoreUrl: string; deepLink: string }) {
  const [copied, setCopied] = useState(false);

  const install = async () => {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
    } catch {}
    window.location.href = appStoreUrl;
  };

  return (
    <div className="stack" style={{ width: "100%" }}>
      <button className="btn btn-primary btn-block" onClick={install}>
        📲 {copied ? "Code copié !" : "Télécharger l'app (code copié)"}
      </button>
      <a className="btn btn-ghost btn-block" href={deepLink}>
        J&apos;ai déjà l&apos;app
      </a>
      <p className="muted small" style={{ textAlign: "center", margin: 0 }}>
        Ton code : <strong style={{ letterSpacing: "0.15em", color: "var(--text)" }}>{code}</strong> — colle-le à
        l&apos;inscription.
      </p>
    </div>
  );
}
