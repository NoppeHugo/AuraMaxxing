type Props = { pseudo: string; thumb?: string; color: string; color2?: string; size?: number };

export function Avatar({ pseudo, thumb, color, color2 = color, size = 44 }: Props) {
  return (
    <div
      className="avatar"
      style={{
        width: size,
        height: size,
        fontSize: size * 0.4,
        background: `linear-gradient(135deg, ${color}, ${color2})`,
        boxShadow: `0 0 ${size / 3}px ${color}88`,
      }}
    >
      {thumb ? <img src={thumb} alt="" /> : pseudo.slice(0, 2).toUpperCase()}
    </div>
  );
}
