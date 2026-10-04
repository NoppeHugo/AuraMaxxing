import { authed } from "@/lib/league/http";
import { deleteAccount, profile } from "@/lib/league/store";

export const dynamic = "force-dynamic";
export const GET = authed((user) => profile(user));
export const DELETE = authed(async (user) => {
  await deleteAccount(user);
  return { ok: true };
});
