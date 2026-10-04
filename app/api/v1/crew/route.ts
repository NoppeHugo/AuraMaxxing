import { authed, body } from "@/lib/league/http";
import { createCrew, crewView } from "@/lib/league/store";

export const dynamic = "force-dynamic";
export const GET = authed((user) => crewView(user));
export const POST = authed(async (user, request) => createCrew(user, (await body(request)).name));
