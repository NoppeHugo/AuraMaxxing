import { authed, body } from "@/lib/league/http";
import { block } from "@/lib/league/store";

export const POST = authed(async (user, request) => {
  await block(user, (await body(request)).userId);
  return { ok: true };
});
