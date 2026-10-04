import { authed, body } from "@/lib/league/http";
import { joinCrew } from "@/lib/league/store";

export const POST = authed(async (user, request) => joinCrew(user, (await body(request)).code));
