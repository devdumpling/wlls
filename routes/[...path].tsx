import { page } from "fresh";
import { NotFound } from "@/components/NotFound.tsx";
import { define } from "@/utils.ts";

export const handler = define.handlers({
  GET(ctx) {
    return page({ path: ctx.url.pathname }, { status: 404 });
  },
});

export default define.page<typeof handler>(({ data }) => <NotFound path={data.path} />);
