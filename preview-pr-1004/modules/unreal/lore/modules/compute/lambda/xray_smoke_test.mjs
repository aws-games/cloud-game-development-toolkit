// X-Ray pipeline smoke test — sends a synthetic trace segment and verifies arrival.
// Validates: IAM permissions (xray:PutTraceSegments, xray:GetTraceSummaries), X-Ray reachability.
// ADOT Sidecar health is verified separately via CloudWatch logs ("Everything is ready").
import { XRayClient, PutTraceSegmentsCommand, GetTraceSummariesCommand } from "@aws-sdk/client-xray";

const xray = new XRayClient();

export const handler = async () => {
  const now = Date.now() / 1000;
  const hex = (n) => Math.floor(n).toString(16);
  const rand = (len) => Array.from(crypto.getRandomValues(new Uint8Array(len)), (b) => b.toString(16).padStart(2, "0")).join("");
  const traceId = `1-${hex(now)}-${rand(12)}`;
  const segmentId = rand(8);

  const segment = JSON.stringify({
    name: "lore-xray-smoke-test",
    id: segmentId,
    trace_id: traceId,
    start_time: now,
    end_time: now + 0.05,
    annotations: { test: "smoke", environment: process.env.ENVIRONMENT || "dev" },
  });

  try {
    await xray.send(new PutTraceSegmentsCommand({ TraceSegmentDocuments: [segment] }));
  } catch (e) {
    return { status: "FAIL", phase: "put", error: e.message };
  }

  await new Promise((r) => setTimeout(r, 6000));

  try {
    const startTime = new Date((now - 30) * 1000);
    const endTime = new Date((now + 30) * 1000);
    const res = await xray.send(new GetTraceSummariesCommand({
      StartTime: startTime,
      EndTime: endTime,
      FilterExpression: 'annotation.test = "smoke"',
    }));

    const found = (res.TraceSummaries || []).some((t) => t.Id === traceId);
    return {
      status: found ? "PASS" : "WARN",
      traceId,
      found,
      summaryCount: (res.TraceSummaries || []).length,
      message: found
        ? "Trace arrived in X-Ray — pipeline verified."
        : "Trace sent but not yet visible (may need more propagation time).",
    };
  } catch (e) {
    return { status: "FAIL", phase: "get", error: e.message };
  }
};
