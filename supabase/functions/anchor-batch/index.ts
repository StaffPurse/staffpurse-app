import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

console.log("anchor-batch function initialized");

serve(async (req) => {
  if (req.method === 'POST') {
    return new Response(
      JSON.stringify({ status: "success", message: "Batch anchored" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }
  
  return new Response(
    JSON.stringify({ message: "anchor-batch is running" }),
    { headers: { "Content-Type": "application/json" } },
  );
});
