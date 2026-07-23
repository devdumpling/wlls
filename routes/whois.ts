import { define } from "@/utils.ts";

export const handler = define.handlers((ctx) => ctx.redirect("/about", 308));
