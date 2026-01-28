const core = require("@actions/core");
const { Octokit } = require("@octokit/rest");
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

async function run() {
  try {
    core.info("Starting CICD Security Scanner...");

    // Get inputs
    const baseRef = core.getInput("base_ref") || "main";
    
    // Step 1: Checkout repository
    core.info("Checking out repository...");
    execSync("git config --global --add safe.directory $(pwd)", { stdio: "inherit" });

    // Step 2: Build Docker image
    core.info("Building scanner image...");
    const actionPath = process.env.GITHUB_ACTION_PATH || ".";
    execSync(`docker build -t cicd-security-scanner ${actionPath}`, { stdio: "inherit" });

    // Step 3: Run secret scanning
    core.info("Running secret scanning...");
    const workspace = process.env.GITHUB_WORKSPACE || process.cwd();
    execSync(
      `docker run --rm -v ${workspace}:/scan -e GITHUB_BASE_REF=${baseRef} cicd-security-scanner`,
      { stdio: "inherit" }
    );

    // Step 4: Check if secrets were found
    const leaksFile = "reports/gitleaks.json";
    if (!fs.existsSync(leaksFile)) {
      core.info("✅ No gitleaks.json found. No leaks detected.");
      await core.summary.addHeading("No secrets detected ✅").write();
      return;
    }

    const leaks = JSON.parse(fs.readFileSync(leaksFile, "utf8"));
    
    if (!Array.isArray(leaks) || leaks.length === 0) {
      core.info("✅ No secrets detected");
      await core.summary.addHeading("No secrets detected ✅").write();
      return;
    }

    // Step 5: Process results
    core.warning(`🛑 ${leaks.length} secret(s) detected`);

    // Generate SARIF report
    generateSARIF(leaks);

    // Read event data
    const eventPath = process.env.GITHUB_EVENT_PATH;
    let eventData = null;
    if (eventPath && fs.existsSync(eventPath)) {
      eventData = JSON.parse(fs.readFileSync(eventPath, "utf8"));
    }

    // Create GitHub summary
    await createSummary(leaks, eventData);

    // Create PR review with detailed info
    if (process.env.GITHUB_EVENT_NAME === "pull_request" && eventData) {
      await createPRReview(leaks, eventData);
    }

    // Fail the action
    core.setFailed("Secrets detected in this PR");

  } catch (error) {
    core.error(`Action failed with error: ${error.message}`);
    process.exit(1);
  }
}

function generateSARIF(leaks) {
  const sarif = {
    version: "2.1.0",
    runs: [
      {
        tool: {
          driver: {
            name: "Gitleaks",
            version: "8.0.0",
            informationUri: "https://github.com/gitleaks/gitleaks",
          },
        },
        results: leaks.map((leak) => ({
          ruleId: leak.RuleID,
          message: {
            text: `Potential ${leak.RuleID} secret detected`,
          },
          locations: [
            {
              physicalLocation: {
                artifactLocation: {
                  uri: leak.File,
                },
                region: {
                  startLine: leak.StartLine,
                },
              },
            },
          ],
          partialFingerprints: {
            commitSha: leak.Commit,
            author: leak.Author,
            date: leak.Date,
            email: leak.Email || "",
          },
        })),
      },
    ],
  };

  fs.writeFileSync("reports/gitleaks.sarif", JSON.stringify(sarif, null, 2));
  core.info("Generated gitleaks.sarif");
}

async function createSummary(leaks, eventData) {
  const repoUrl = eventData?.repository?.html_url || "";
  
  const resultsHeader = [
    { data: "Rule ID", header: true },
    { data: "Commit", header: true },
    { data: "Line", header: true },
    { data: "Author", header: true },
    { data: "Date", header: true },
    { data: "File", header: true },
  ];

  const resultsRows = leaks.map((leak) => {
    const commitUrl = repoUrl ? `${repoUrl}/commit/${leak.Commit}` : "";
    const fileUrl = repoUrl ? `${repoUrl}/blob/${leak.Commit}/${leak.File}#L${leak.StartLine}` : "";
    
    return [
      leak.RuleID,
      commitUrl ? `<a href="${commitUrl}">${leak.Commit.substring(0, 7)}</a>` : leak.Commit.substring(0, 7),
      leak.StartLine.toString(),
      leak.Author,
      new Date(leak.Date).toLocaleDateString(),
      fileUrl ? `<a href="${fileUrl}">${leak.File}</a>` : leak.File,
    ];
  });

  const summary = core.summary
    .addHeading("🛑 Secrets Audit Summary 🛑")
    .addTable([resultsHeader, ...resultsRows])
    .addBreak()
    .addHeading("Action Required")
    .addList([
      "❌ Do NOT merge this PR",
      "🔄 Rotate exposed secrets immediately",
      "🧹 Remove secrets from code",
      "📝 Force push to update commits",
      "✅ Re-run scan after fixing",
    ]);

  await summary.write();
  core.info("Created summary");
}

async function createPRReview(leaks, eventData) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    core.warning("GITHUB_TOKEN not available, skipping PR review");
    return;
  }

  const octokit = new Octokit({ auth: token });
  const repo = eventData.repository;
  const pullNumber = eventData.pull_request?.number;

  if (!pullNumber) {
    core.warning("Pull request number not available, skipping PR review");
    return;
  }

  let tableMarkdown = "| Rule ID | Commit | Line | Author | Date | File |\n";
  tableMarkdown += "|---------|--------|------|--------|------|------|\n";

  leaks.forEach((leak) => {
    tableMarkdown += `| ${leak.RuleID} | ${leak.Commit.substring(0, 7)} | ${leak.StartLine} | ${leak.Author} | ${new Date(leak.Date).toLocaleDateString()} | ${leak.File} |\n`;
  });

  const body = `⚠️ **Secret Scanning Alert** ⚠️\n\n🔐 Potential secrets detected in this PR!\n\n## Detected Secrets\n\n${tableMarkdown}\n\n**Action Required:**\n- ❌ Do NOT merge\n- 🔄 Rotate exposed secrets immediately\n- 🧹 Remove secrets from code\n- 📝 Force push to update commits\n- ✅ Re-run scan`;

  try {
    await octokit.rest.pulls.createReview({
      owner: repo.owner.login,
      repo: repo.name,
      pull_number: pullNumber,
      body: body,
      event: "COMMENT",
    });
    core.info("Created PR review");
  } catch (error) {
    core.warning(`Failed to create PR review: ${error.message}`);
  }
}

run();
