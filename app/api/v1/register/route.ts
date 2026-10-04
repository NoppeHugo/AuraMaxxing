import { errorResponse, rateLimit } from "@/lib/input";
import { body } from "@/lib/league/http";
import { register } from "@/lib/league/store";

export async function POST(request: Request) {
  try {
    rateLimit(request, 5);
    return Response.json(await register((await body(request)).pseudo));
  } catch (error) {
    return errorResponse(error);
  }
}
