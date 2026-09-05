import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import ts from "typescript";
import { expect, it } from "vitest";

it("disables dotenv loading at the shared top-level Vitest configuration boundary", async () => {
  const text = await readFile(resolve("vitest.config.mts"), "utf8");
  const source = ts.createSourceFile("vitest.config.mts", text, ts.ScriptTarget.Latest, true);
  const declaration = source.statements.find(ts.isExportAssignment);
  if (!declaration || !ts.isCallExpression(declaration.expression)) {
    throw new Error("Expected one exported configuration call.");
  }
  const call = declaration.expression;
  expect(call.expression.getText(source)).toBe("defineConfig");
  expect(call.arguments).toHaveLength(1);
  const configuration = call.arguments[0];
  if (!configuration || !ts.isObjectLiteralExpression(configuration)) {
    throw new Error("Expected a literal top-level configuration.");
  }
  const envProperties: ts.PropertyAssignment[] = [];
  const visit = (node: ts.Node): void => {
    if (
      ts.isPropertyAssignment(node) &&
      (ts.isIdentifier(node.name) || ts.isStringLiteral(node.name)) &&
      node.name.text === "envDir"
    ) {
      envProperties.push(node);
    }
    ts.forEachChild(node, visit);
  };
  visit(source);
  expect(envProperties).toHaveLength(1);
  expect(configuration.properties).toContain(envProperties[0]);
  expect(envProperties[0]?.initializer.kind).toBe(ts.SyntaxKind.FalseKeyword);
  expect(text.match(/\benvDir\b/gu)).toHaveLength(1);
  expect(text).not.toMatch(/\bloadEnv\b/u);

  const manifest = JSON.parse(await readFile(resolve("package.json"), "utf8")) as {
    scripts: Record<string, string>;
  };
  expect(manifest.scripts["infra:test"]).toBe("vitest run tests/infra");
  expect(manifest.scripts.test).toBe("vitest run");
});
