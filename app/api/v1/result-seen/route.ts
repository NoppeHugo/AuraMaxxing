import { authed } from "@/lib/league/http";
import { markResultSeen } from "@/lib/league/store";

export const POST = authed(async (user) => {
  await markResultSeen(user);
  return { ok: true };
});
