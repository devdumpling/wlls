import { serializeJsonLd } from "../src/site.ts";

Deno.test("serializeJsonLd cannot terminate its script element", () => {
  const headline = "</script><script>alert('unsafe')</script>";
  const serialized = serializeJsonLd({ headline });

  if (serialized.includes("<")) throw new Error("Serialized JSON-LD contains a raw angle bracket");
  const parsed = JSON.parse(serialized);
  if (parsed.headline !== headline) throw new Error("Serialized JSON-LD changed its input value");
});
