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
    expect(caddy.match(/bind 127\.0\.0\.1/g)).toHaveLength(2);
    expect(caddy).toContain("reverse_proxy 127.0.0.1:3100");
    expect(caddy).toContain("persist_config off");
    expect(caddy).toContain("local_certs");
    expect(caddy).toContain("max_header_size 32KB");
    expect(caddy).toContain("max_size 1MB");
    expect(caddy).toContain("flush_interval -1");
    expect(caddy).not.toContain("header_up -X-Forwarded-*");
    expect(caddy).toContain("header_up X-Forwarded-For {remote_host}");
    expect(caddy).toContain("header_up X-Forwarded-Host {host}");
    expect(caddy).toContain("header_up X-Forwarded-Proto https");
    expect(caddy).toContain("request>headers>Authorization delete");
    expect(caddy).toContain("replace token REDACTED");
    expect(caddy).toContain("respond @internal 404");
    expect(caddy).not.toMatch(/(^|\s)(0\.0\.0\.0|:80\s|:443\s)/m);
  });

  it("uses pinned Node and an explicit local CA for every HTTPS behavior probe", async () => {
    const health = await text("scripts/infra/Test-RisePalsHealth.ps1");
    const probe = await text("scripts/infra/loopback-https-probe.mjs");

    expect(health).toContain("tools\\node\\24.18.1\\node.exe");
    expect(health.match(/& \$node \$probe --ca \$ca/g)).toHaveLength(4);
    expect(health).not.toContain("curl.exe --silent --show-error --cacert");
    expect(probe).toContain('url.hostname !== "127.0.0.1"');
    expect(probe).toContain('url.port !== "8443"');
    expect(probe).toContain("rejectUnauthorized: true");
    expect(health).toContain('--body-base64 "eyJzdGF0dXMiOiJvayJ9"');
    expect(probe).toContain('input["body-base64"]');
    expect(probe).toContain("Unexpected loopback HTTPS status: ${result.status}");
    expect(probe).toContain("maximumFirstByteMs");
    expect(probe).toContain("minimumTotalMs");
    expect(probe).toContain("approvedFirstByteMarker");
    expect(probe).toContain('writeFileSync(firstByteMarker, "started\\n"');
  });

  it("keeps WinSW stable, manual, least-privilege and bounded", async () => {
    const xml = await text("infra/windows/winsw/RisePalsApp.xml");
    expect(xml).toContain("<id>RisePalsApp</id>");
    expect(xml).toContain("<domain>NT SERVICE</domain>");
    expect(xml).toContain("<user>RisePalsApp</user>");
    expect(xml).toContain("<startmode>Manual</startmode>");
    expect(xml).toContain("<autoRefresh>false</autoRefresh>");
    expect(xml).toContain(
      "<startarguments>C:\\RisePals\\current\\rise-pals-standalone-server.mjs</startarguments>",
    );
    expect(xml).toContain(
      "<stopexecutable>C:\\RisePals\\tools\\node\\24.18.1\\node.exe</stopexecutable>",
    );
    expect(xml).toContain(
      "<stoparguments>C:\\RisePals\\current\\request-rise-pals-drain.mjs</stoparguments>",
    );
    expect(xml).toContain("<stoptimeout>20 sec</stoptimeout>");
    expect(xml).not.toContain("<arguments>");
    expect(xml).toContain('<log mode="roll-by-size">');
    expect(xml.match(/<onfailure /g)).toHaveLength(3);
    expect(xml).toContain('<onfailure action="none" />');
    expect(xml).not.toMatch(/LocalSystem|NetworkService|roll-by-size-time|password/i);
  });

  it("grants only non-inheriting application traversal at the secret directory", async () => {
    const installer = await text("scripts/infra/Install-RisePalsServices.ps1");
    const repair = await text("scripts/infra/Repair-RisePalsSecretTraversal.ps1");

    for (const script of [installer, repair]) {
      expect(script).toContain('Identity = "NT SERVICE\\RisePalsApp"');
      expect(script).toContain('Rights = "Traverse"');
      expect(script).toContain('InheritanceFlags = "None"');
    }
    expect(repair).toContain("$_.IdentityReference.Value");
    expect(repair).toContain('"NT SERVICE\\RisePalsProxy"');
    expect(repair).not.toMatch(
      /Identity\s*=\s*"NT SERVICE\\RisePalsApp"\s+Rights\s*=\s*"(Read|ReadAndExecute|Modify|FullControl)"/,
    );
  });

  it("restricts the local drain control to administrators, SYSTEM and the app identity", async () => {
    const installer = await text("scripts/infra/Install-RisePalsServices.ps1");
    const updater = await text("scripts/infra/Update-RisePalsDrainControl.ps1");
    const snapshot = await text("scripts/infra/Get-RisePalsDrainAclSnapshot.ps1");
    const control = await text("scripts/infra/drain-control.mjs");
    const launcher = await text("scripts/infra/rise-pals-standalone-server.mjs");
    const stopHelper = await text("scripts/infra/request-rise-pals-drain.mjs");

    for (const script of [installer, updater]) {
      expect(script).toContain('"shared\\control"');
      expect(script).toContain('Identity = "NT SERVICE\\RisePalsApp"; Rights = "Modify"');
    }
    expect(updater).toContain('@("RisePalsApp", "RisePalsProxy")');
    expect(updater).not.toContain('Identity = "NT SERVICE\\RisePalsProxy"');
    expect(updater).not.toMatch(/FullControl.*RisePalsApp|RisePalsProxy.*(Read|Modify)/);
    expect(updater).toContain("--assert-parent");
    expect(snapshot).toContain("GetAccessRules(");
    expect(snapshot).toContain("[int64]$Rule.FileSystemRights");
    expect(snapshot).toContain("[Security.Principal.SecurityIdentifier]");
    expect(control).toContain("modifySynchronize: 1_245_631");
    expect(control).toContain("rule.rightsMask !== expectedBySid.get(rule.sid)");
    expect(control).toContain("rule.accessControlType !== allowAccessControlType");
    expect(control).toContain("rule.isInherited !== inherited");
    expect(control).not.toContain("HasFlag");
    expect(control).toContain('url === "/health/ready"');
    expect(launcher).toContain('"Retry-After": "5"');
    expect(launcher).toContain("activeRequests");
    expect(stopHelper).toContain("requestDrain()");
    expect(`${control}\n${launcher}\n${stopHelper}`).not.toMatch(
      /token|secret|cookie|authorization/i,
    );
  });

  it("diagnoses readiness under the real app identity without opening a listener", async () => {
    const diagnostic = await text("scripts/infra/Invoke-RisePalsReadinessDiagnostic.ps1");

    expect(diagnostic).toContain("RISE_PALS_INFRA_REHEARSAL");
    expect(diagnostic).toContain("markerReadable");
    expect(diagnostic).toContain("canaryReadable");
    expect(diagnostic).toContain("setInterval(() => {}, 1000)");
    expect(diagnostic).toContain("[IO.File]::WriteAllBytes($installedConfig, $originalConfig)");
    expect(diagnostic).not.toMatch(/Start-RisePalsRehearsal|New-NetFirewallRule|Restart-Computer/);
  });

  it("passes SCM option names and values as distinct native arguments", async () => {
    const installer = await text("scripts/infra/Install-RisePalsServices.ps1");
    expect(installer).toContain('"binPath=",');
    expect(installer).toContain('"start=",');
    expect(installer).toContain('"demand",');
    expect(installer).toContain('"obj=",');
    expect(installer).toContain('"NT SERVICE\\RisePalsApp"');
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
        name !== "rehearsal-launcher-result.ps1" &&
        name !== "candidate-rehearsal-contract.ps1" &&
        name !== "candidate-rehearsal-result.ps1" &&
        name !== "candidate-rehearsal-transport.ps1" &&
        name !== "windows-powershell-security-bootstrap.ps1" &&
        name !== "Invoke-RisePalsLauncherFixture.ps1" &&
        !name.startsWith("Get-") &&
        !name.startsWith("Test-"),
    );
    expect(names.length).toBeGreaterThanOrEqual(6);
    for (const name of names) {
      const script = await readFile(join(directory, name), "utf8");
      expect(script).toContain("SupportsShouldProcess = $true");
      expect(script).toContain("Set-StrictMode -Version Latest");
      expect(script).toContain('$ErrorActionPreference = "Stop"');
      if (
        !["Invoke-RisePalsServiceStop.ps1", "Invoke-RisePalsCandidateServiceControl.ps1"].includes(
          name,
        )
      ) {
        expect(script).toMatch(/-LiteralPath|\[IO\.Directory\]/);
      }
      expect(script).not.toMatch(
        /Write-(Output|Host).*\$(bytes|secret(Value|Content)|canary(Value|Content))/i,
      );
    }
  });

  it("deletes validated staging trees without traversing reparse-point targets", async () => {
    const common = await text("scripts/infra/common.ps1");
    const rehearsal = await text("scripts/infra/Invoke-RisePalsNonRebootRehearsal.ps1");

    expect(common).toContain("[IO.FileAttributes]::ReparsePoint");
    expect(common).toContain("[IO.Directory]::Delete($EntryPath)");
    expect(common).toContain("[IO.Directory]::Delete($validated)");
    expect(common).toContain("requires an explicit validated recursive cleanup");
    expect(common).toContain("EnumerateFileSystemEntries($EntryPath)");
    expect(rehearsal).toContain('"^build-[a-f0-9]{32}$"');
    expect(rehearsal).toContain("unexpectedly active before staging recovery");
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
    expect(preparation).toContain('"rise-pals-standalone-server.mjs"');
    expect(preparation).toContain('"request-rise-pals-drain.mjs"');
    expect(preparation).toContain('"drain-control.mjs"');
    expect(preparation).toContain('"Get-RisePalsDrainAclSnapshot.ps1"');
    expect(release).toContain("& $npm run build");
    expect(release).not.toContain('"scripts\\run-secret-free.mjs" build');
  });

  it("keeps releases immutable, cache writable and switches with automatic service rollback", async () => {
    const release = await text("scripts/infra/New-RisePalsRelease.ps1");
    const switching = await text("scripts/infra/Switch-RisePalsRelease.ps1");
    const readinessRoute = await text("src/app/health/ready/route.ts");

    expect(release).toContain('Identity = "NT SERVICE\\RisePalsApp"; Rights = "ReadAndExecute"');
    expect(release).toContain('Identity = "NT SERVICE\\RisePalsApp"; Rights = "Modify"');
    expect(release).toContain("ReuseExactExisting");
    expect(release).toContain("--mode verify");
    expect(release).toContain("merge-base --is-ancestor");
    expect(release).toContain('"release-created"');
    expect(release).toContain("RehearsalDenyManifestRead");
    expect(release).toContain('"release-created-unready"');
    expect(switching).toContain('Stop-Service -Name "RisePalsApp"');
    expect(switching).toContain('Start-Service -Name "RisePalsApp"');
    expect(switching).toContain('Event "automatic-rollback"');
    expect(switching).toContain("prior release did not recover readiness");
    expect(readinessRoute).toContain("const marker = await readFile(path)");
    expect(readinessRoute).toContain("return marker.byteLength > 0");
    expect(readinessRoute).not.toContain("access(path, constants.R_OK)");
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

  it("orchestrates bounded non-reboot evidence and cleanup without public mutations", async () => {
    const rehearsal = await text("scripts/infra/Invoke-RisePalsNonRebootRehearsal.ps1");
    const cleanup = await text("scripts/infra/Clear-RisePalsRehearsal.ps1");
    const serviceStop = await text("scripts/infra/Invoke-RisePalsServiceStop.ps1");

    expect(rehearsal).toContain('branch -ne "agent/windows-vps-infrastructure-readiness"');
    expect(rehearsal).toContain("RehearsalDenyManifestRead");
    expect(rehearsal).toContain("automaticRollback");
    expect(rehearsal).toContain("boundedCrashRecovery");
    expect(rehearsal).toContain("certificateReissueAndReload");
    expect(rehearsal).toContain("Set-RisePalsRehearsalSecret.ps1");
    expect(rehearsal).toContain("Clear-RisePalsRehearsal.ps1");
    expect(rehearsal).toContain("stopped-service Caddy configuration synchronization PASS");
    expect(rehearsal).toContain("[IO.File]::WriteAllBytes($installedCaddyConfig");
    expect(rehearsal).toContain("existingCurrentIsVerifiedAncestor");
    expect(rehearsal).toContain(
      "merge-base --is-ancestor ([string]$existingManifest.sourceCommit) $head",
    );
    expect(rehearsal).toContain("--mode verify --root $existingRelease");
    expect(rehearsal).toContain("[AllowEmptyCollection()][byte[]]$Haystack");
    expect(rehearsal).toContain("[IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete");
    expect(rehearsal).toContain('"tools\\node\\24.18.1\\node.exe"');
    expect(rehearsal).toContain('"--first-byte-marker", $startedMarker');
    expect(rehearsal).toContain("Direct Stop-Service did not enter the exact local Draining state");
    expect(rehearsal).toContain("--assert-parent");
    expect(rehearsal).toContain("--assert-state");
    expect(rehearsal).toContain("Invoke-RisePalsServiceStop.ps1");
    expect(rehearsal).not.toContain('"-Command"');
    expect(serviceStop).toContain("Stop-Service -Name $ServiceName");
    expect(serviceStop).toContain('[ValidateSet("RisePalsApp")]');
    expect(rehearsal).toContain('response-header "Retry-After: 5"');
    expect(rehearsal).toContain("persistentStartupAttempts");
    expect(rehearsal).toContain("startup-state-invalid fail-closed");
    expect(rehearsal).toContain("if (-not $streamStarted)");
    expect(rehearsal).not.toContain('Start-Process -FilePath "curl.exe"');
    expect(rehearsal).toContain("Read-RisePalsSharedFileBytes -Path $path");
    expect(rehearsal).toContain("finalAtomicTemporaryCount");
    expect(rehearsal).not.toMatch(/New-NetFirewallRule|Restart-Computer|\.env\.local/);
    expect(cleanup).toContain('"app-drain-state.json"');
    expect(cleanup).toContain('"app-drain-state.json.lock"');
    expect(cleanup).toContain('"^\\.app-drain-state\\.[0-9]+\\.[a-f0-9-]{36}\\.tmp$"');
    expect(cleanup).toContain("Remove-RisePalsValidatedChild");
  });

  it("keeps the reboot checkpoint separate, explicit and cleanup-bound", async () => {
    const prepare = await text("scripts/infra/Prepare-RisePalsRebootCheckpoint.ps1");
    const complete = await text("scripts/infra/Complete-RisePalsRebootCheckpoint.ps1");

    expect(prepare).toContain("ExpectedSourceCommit");
    expect(prepare).toContain('"start=", "auto"');
    expect(prepare).toContain("no reboot was initiated");
    expect(prepare).not.toContain("Restart-Computer");
    expect(complete).toContain("LastBootUpTime");
    expect(complete).toContain("Clear-RisePalsRehearsal.ps1");
    expect(complete).toContain('finalServiceState = "Stopped/Disabled"');
  });
});
