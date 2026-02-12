const fs = require('fs');

module.exports = async ({ github, context }) => {
  const sarif = JSON.parse(fs.readFileSync('results.sarif', 'utf8'));
  const results = sarif.runs?.[0]?.results || [];
  const rules = sarif.runs?.[0]?.tool?.driver?.rules || [];

  // If Code Scanning Alerts are active for this tool, skip PR inline comments.
  const toolName = (sarif.runs?.[0]?.tool?.driver?.name || 'Checkov').toString();
  try {
    const alertsResp = await github.rest.codeScanning.listAlertsForRepo({ owner: context.repo.owner, repo: context.repo.repo, tool_name: toolName });
    const alerts = alertsResp.data || [];
    if (alerts.length > 0) {
      console.log(`Code scanning alerts present for tool '${toolName}' — skipping inline PR comments.`);
      return;
    }
  } catch (err) {
    console.log(`Could not check Code Scanning Alerts (will proceed to post comments): ${err.message}`);
  }

  if (results.length === 0) return;

  const { owner, repo } = context.repo;
  const pull_number = context.issue.number;

  // Build rule index for details
  const ruleIndex = {};
  for (const rule of rules) {
    ruleIndex[rule.id] = rule;
  }

  const { data: pr } = await github.rest.pulls.get({
    owner, repo, pull_number,
  });

  const commitId = pr.head.sha;

  const { data: files } = await github.rest.pulls.listFiles({
    owner, repo, pull_number, per_page: 100,
  });

  // Detect which files are new
  const newFiles = new Set(
    files.filter(f => f.status === "added").map(f => f.filename)
  );

  // Build positionMap only for modified files
  const positionMap = {};

  for (const file of files) {
    if (!file.patch) continue;

    const lines = file.patch.split('\n');
    let position = 0;
    let fileLine = 0;

    for (const l of lines) {
      position++;

      if (l.startsWith('@@')) {
        const match = /\+(\d+)/.exec(l);
        if (match) {
          fileLine = parseInt(match[1], 10) - 1;
        }
        continue;
      }

      if (l.startsWith('+++') || l.startsWith('---')) continue;

      if (!l.startsWith('-')) {
        fileLine++;
      }

      if (!positionMap[file.filename]) positionMap[file.filename] = {};
      positionMap[file.filename][fileLine] = position;
    }
  }

  // Get severity from rule or message
  const getSeverity = (result) => {
    const rule = ruleIndex[result.ruleId];
    // Checkov uses level in defaultConfiguration
    if (rule?.defaultConfiguration?.level === 'error') return '🔴 HIGH';
    if (rule?.defaultConfiguration?.level === 'warning') return '🟡 MEDIUM';
    // Try to extract from message
    const msg = result.message?.text || '';
    if (msg.includes('CRITICAL') || msg.includes('HIGH')) return '🔴 HIGH';
    if (msg.includes('MEDIUM')) return '🟡 MEDIUM';
    return '🟢 LOW';
  };

  for (const r of results) {
    const loc = r.locations?.[0]?.physicalLocation;
    if (!loc) continue;

    const path = loc.artifactLocation?.uri;
    const line = loc.region?.startLine || 1;
    if (!path) continue;

    const ruleId = r.ruleId || "IaC misconfiguration";
    const message = r.message?.text || "Infrastructure misconfiguration found";
    const severity = getSeverity(r);
    const rule = ruleIndex[ruleId];
    const helpUri = rule?.helpUri || '';

    // Extract check name if available
    const checkName = rule?.shortDescription?.text || ruleId;

    const body = `🏗️ **IaC Misconfiguration** ${severity}

**Check:** \`${checkName}\`  
**Rule:** \`${ruleId}\`  
**Details:** ${message}
${helpUri ? `\n📚 [Remediation guide](${helpUri})` : ''}

🔧 Fix this infrastructure misconfiguration before deploying.`;

    try {
      if (newFiles.has(path)) {
        await github.rest.pulls.createReview({
          owner,
          repo,
          pull_number,
          event: "COMMENT",
          comments: [{
            path,
            line,
            side: "RIGHT",
            body
          }]
        });
        console.log(`Commented (new file) on ${path}:${line}`);
      } else {
        const pos = positionMap[path]?.[line];
        if (!pos) {
          console.log(`Skipping ${path}:${line} - not in PR diff`);
          continue;
        }

        await github.rest.pulls.createReviewComment({
          owner,
          repo,
          pull_number,
          commit_id: commitId,
          path,
          position: pos,
          body
        });
        console.log(`Commented on ${path}:${line}`);
      }
    } catch (e) {
      console.log(`Failed on ${path}:${line}: ${e.message}`);
    }
  }
};
