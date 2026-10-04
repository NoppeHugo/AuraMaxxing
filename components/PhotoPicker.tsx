"use client";

import { useRef } from "react";
import { resizeImage, squareThumb } from "@/lib/image";

export type Photo = { preview: string; image: string; thumb: string };

export function PhotoPicker({
  photo,
  onChange,
  label = "Ajoute ta photo",
}: {
  photo: Photo | null;
  onChange: (p: Photo) => void;
  label?: string;
}) {
  const input = useRef<HTMLInputElement>(null);

  const handle = async (file: File | undefined) => {
    if (!file) return;
    const [image, thumb] = await Promise.all([resizeImage(file, 1024), squareThumb(file)]);
    onChange({ preview: image, image, thumb });
  };

  return (
    <button type="button" className="picker" onClick={() => input.current?.click()}>
      {photo ? (
        <>
          <img src={photo.preview} alt="Photo choisie" />
          <span className="picker-change">Changer</span>
        </>
      ) : (
        <>
          <span className="picker-icon">📸</span>
          <strong>{label}</strong>
          <span className="muted small">Fit, selfie, pose… JPEG ou PNG</span>
        </>
      )}
      <input
        ref={input}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        hidden
        onChange={(e) => handle(e.target.files?.[0])}
      />
    </button>
  );
}
