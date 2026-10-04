import { authed, body } from "@/lib/league/http";
import { report } from "@/lib/league/store";

export const POST = authed(async (user, request) => {
  await report(user, (await body(request)).userId);
  return { ok: true };
});
