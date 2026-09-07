import { NextResponse } from "next/server";
import { getPortfolioView } from "@/lib/etoro/portfolio";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const view = await getPortfolioView();
    return NextResponse.json(view);
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Failed to load portfolio" },
      { status: 502 },
    );
  }
}
