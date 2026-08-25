import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const repositoryRoot = process.cwd();

async function text(path: string): Promise<string> {
  return readFile(join(repositoryRoot, path), "utf8");
}

describe("Windows infrastructure contract", () => {
  it("pins the three authorized tools with exact official metadata", async () => {
    const manifest = JSON.parse(await text("infra/windows/tool-manifest.json")) as {
      schemaVersion: string;
      tools: Array<Record<string, unknown>>;
    };
    expect(manifest.schemaVersion).toBe("rise-pals-windows-tool-manifest-v1");
    expect(manifest.tools.map(({ name, version }) => [name, version])).toEqual([
      ["node", "24.18.1"],
      ["caddy", "2.11.4"],
      ["winsw", "2.12.0"],
    ]);
    for (const tool of manifest.tools) {
      expect(tool.sourceUrl).toMatch(/^https:\/\/(nodejs\.org|github\.com)\//);
      expect(tool.length).toEqual(expect.any(Number));
      expect(tool.sha256).toMatch(/^[a-f0-9]{64}$/);
    }
  });

  it("keeps Caddy on exact loopback ports with bounded safe proxy behavior", async () => {
    const caddy = await text("infra/windows/caddy/Caddyfile");
    expect(caddy).toContain("admin 127.0.0.1:2019");
    expect(caddy).toContain("http://127.0.0.1:8080");
    expect(caddy).toContain("https://127.0.0.1:8443");
    expect(caddy).toContain("reverse_proxy 127.0.0.1:3100");
    expect(caddy).toContain("persist_config off");
    expect(caddy).toContain("local_certs");
    expect(caddy).toContain("max_header_size 32KB");
    expect(caddy).toContain("max_size 1MB");
    expect(caddy).toContain("flush_interval -1");
    expect(caddy).toContain("header_up -X-Forwarded-*");
    expect(caddy).toContain("request>headers>Authorization delete");
    expect(caddy).toContain("replace token REDACTED");
    expect(caddy).toContain("respond @internal 404");
    expect(caddy).not.toMatch(/(^|\s)(0\.0\.0\.0|:80\s|:443\s)/m);
  });

  it("keeps WinSW stable, manual, least-privilege and bounded", async () => {
    const xml = await text("infra/windows/winsw/RisePalsApp.xml");
    expect(xml).toContain("<id>RisePalsApp</id>");
    expect(xml).toContain("<username>NT SERVICE\\RisePalsApp</username>");
    expect(xml).toContain("<startmode>Manual</startmode>");
    expect(xml).toContain("<autoRefresh>false</autoRefresh>");
    expect(xml).toContain('<log mode="roll-by-size">');
    expect(xml.match(/<onfailure /g)).toHaveLength(3);
    expect(xml).toContain('<onfailure action="none" />');
    expect(xml).not.toMatch(/LocalSystem|NetworkService|roll-by-size-time|password/i);
  });

  it("passes SCM option names and values as distinct native arguments", async () => {
    const installer = await text("scripts/infra/Install-RisePalsServices.ps1");
    expect(installer).toContain('"binPath=",');
    expect(installer).toContain('"start=",');
    expect(installer).toContain('"demand",');
    expect(installer).toContain('"obj=",');
    expect(installer).not.toContain('"start= demand"');
  });

  it("keeps future firewall rules disabled and proxy-only", async () => {
    const template = JSON.parse(
      await text("infra/windows/firewall/future-public-proxy-rules.json"),
    ) as {
      enabled: boolean;
      rules: Array<{ service: string; localPort: number }>;
      prohibitedPublicServices: string[];
    };
    expect(template.enabled).toBe(false);
    expect(template.rules).toHaveLength(2);
    expect(template.rules.every((rule) => rule.service === "RisePalsProxy")).toBe(true);
    expect(
      template.rules.map((rule) => rule.localPort).sort((left, right) => left - right),
    ).toEqual([80, 443]);
    expect(template.prohibitedPublicServices).toEqual(["RisePalsApp", "PostgreSQL"]);
  });

  it("requires dry-run support and LiteralPath in every mutating PowerShell script", async () => {
    const directory = join(repositoryRoot, "scripts", "infra");
    const names = (await readdir(directory)).filter(
      (name) =>
        name.endsWith(".ps1") &&
        name !== "common.ps1" &&
        !name.startsWith("Get-") &&
        !name.startsWith("Test-"),
    );
    expect(names.length).toBeGreaterThanOrEqual(6);
    for (const name of names) {
      const script = await readFile(join(directory, name), "utf8");
      expect(script).toContain("SupportsShouldProcess = $true");
      expect(script).toContain("Set-StrictMode -Version Latest");
      expect(script).toContain('$ErrorActionPreference = "Stop"');
      expect(script).toMatch(/-LiteralPath|\[IO\.Directory\]/);
      expect(script).not.toMatch(
        /Write-(Output|Host).*\$(bytes|secret(Value|Content)|canary(Value|Content))/i,
      );
    }
  });

  it("prepares and launches the same secret-free standalone runtime used by releases", async () => {
    const packageJson = JSON.parse(await text("package.json")) as {
      scripts: Record<string, string>;
    };
    const runner = await text("scripts/run-secret-free.mjs");
    const preparation = await text("scripts/prepare-standalone.mjs");
    const release = await text("scripts/infra/New-RisePalsRelease.ps1");

    expect(packageJson.scripts.build).toContain("scripts/prepare-standalone.mjs");
    expect(runner).toContain('start: resolve(".next/standalone/server.js")');
    expect(runner).toContain('value !== "127.0.0.1"');
    expect(preparation).toContain('entry.name.startsWith(".env.")');
    expect(preparation).toContain('resolve(outputRoot, ".next/static")');
    expect(release).toContain("& $npm run build");
    expect(release).not.toContain('"scripts\\run-secret-free.mjs" build');
  });

  it("keeps releases immutable, cache writable and switches with automatic service rollback", async () => {
    const release = await text("scripts/infra/New-RisePalsRelease.ps1");
    const switching = await text("scripts/infra/Switch-RisePalsRelease.ps1");

    expect(release).toContain('Identity = "NT SERVICE\\RisePalsApp"; Rights = "ReadAndExecute"');
    expect(release).toContain('Identity = "NT SERVICE\\RisePalsApp"; Rights = "Modify"');
    expect(release).toContain('"release-created"');
    expect(release).toContain("RehearsalDenyManifestRead");
    expect(release).toContain('"release-created-unready"');
    expect(switching).toContain('Stop-Service -Name "RisePalsApp"');
    expect(switching).toContain('Start-Service -Name "RisePalsApp"');
    expect(switching).toContain('Event "automatic-rollback"');
    expect(switching).toContain("prior release did not recover readiness");
  });

  it("rehearses disposable PostgreSQL TLS with an explicit local CA", async () => {
    const tls = await text("scripts/db/run-disposable-postgres-tls.ps1");

    expect(tls).toContain('$env:PGSSLMODE = "verify-full"');
    expect(tls).toContain("$env:PGSSLROOTCERT = $caCertificate");
    expect(tls).toContain("-c ssl=on");
    expect(tls).toContain("rise_pals_tls_owner");
    expect(tls).toContain("rise_pals_tls_app");
    expect(tls).toContain("[IO.Directory]::Delete($resolvedTemporary, $true)");
  });
});
