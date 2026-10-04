import { errorResponse, rateLimit } from "@/lib/input";
import { body } from "@/lib/league/http";
import { register } from "@/lib/league/store";

export async function POST(request: Request) {
  try {
    rateLimit(request, 5);
    const b = await body(request);
    // `ref` : code de défi ou pseudo du pote qui a invité (parrainage).
    return Response.json(await register(b.pseudo, b.ref));
  } catch (error) {
    return errorResponse(error);
  }
}
