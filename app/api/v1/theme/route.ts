import { themeOfDay } from "@/lib/league/store";
import { dayEndsAt } from "@/lib/league/time";

export const dynamic = "force-dynamic";

export function GET() {
  return Response.json({ ...themeOfDay(), endsAt: dayEndsAt() });
}
