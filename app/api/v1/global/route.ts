import { authed } from "@/lib/league/http";
import { globalView } from "@/lib/league/store";

export const dynamic = "force-dynamic";
export const GET = authed((user) => globalView(user));
