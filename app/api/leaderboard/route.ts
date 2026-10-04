import { leaderboard } from "@/lib/store";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const by = new URL(request.url).searchParams.get("by") === "aura" ? "aura" : "elo";
  return Response.json(await leaderboard(by));
}
