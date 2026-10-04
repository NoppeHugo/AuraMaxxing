import { authed } from "@/lib/league/http";
import { lobbyView } from "@/lib/league/store";

export const dynamic = "force-dynamic";
export const GET = authed((user) => lobbyView(user));
