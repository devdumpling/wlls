import { createDefine } from "fresh";

export type State = Record<never, never>;

export const define = createDefine<State>();
