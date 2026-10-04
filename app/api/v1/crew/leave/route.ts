import { authed } from "@/lib/league/http";
import { leaveCrew } from "@/lib/league/store";

export const POST = authed(async (user) => {
  await leaveCrew(user);
  return { ok: true };
});
