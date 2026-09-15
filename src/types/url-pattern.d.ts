// Next 16.3 declares browser URLPattern globals that TypeScript 5.9 does not yet
// include. Reuse Node 24's types instead of disabling dependency type checking.
import type { URLPatternInit, URLPatternOptions as NodeURLPatternOptions } from "node:url";

declare global {
  type URLPatternInput = string | URLPatternInit;
  type URLPatternOptions = NodeURLPatternOptions;
}
