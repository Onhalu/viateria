import { NextResponse } from "next/server";
import { getEnvironment, isDemoMode, isSsoConfigured } from "@/lib/etoro/config";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json({
    status: "ok",
    service: "viateria",
    mode: isDemoMode() ? "demo" : "live",
    environment: getEnvironment(),
    ssoConfigured: isSsoConfigured(),
    time: new Date().toISOString(),
  });
}
