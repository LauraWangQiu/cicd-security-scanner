const fs = require('fs');

module.exports = async ({ github, context }) => {
  const sarif = JSON.parse(fs.readFileSync('results.sarif', 'utf8'));
  const results = sarif.runs?.[0]?.results || [];
  const rules = sarif.runs?.[0]?.tool?.driver?.rules || [];

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

  // Get severity from rule
  const getSeverity = (result) => {
    const rule = ruleIndex[result.ruleId];
    if (rule?.properties?.['security-severity']) {
      const score = parseFloat(rule.properties['security-severity']);
      if (score >= 9.0) return '🔴 CRITICAL';
      if (score >= 7.0) return '🟠 HIGH';
      if (score >= 4.0) return '🟡 MEDIUM';
      return '🟢 LOW';
    }
    const msg = result.message?.text || '';
    const severityMatch = msg.match(/Severity:\s*(CRITICAL|HIGH|MEDIUM|LOW)/i);
    if (severityMatch) {
      const sev = severityMatch[1].toUpperCase();
      const icons = { CRITICAL: '🔴', HIGH: '🟠', MEDIUM: '🟡', LOW: '🟢' };
      return `${icons[sev] || ''} ${sev}`;
    }
    return '🟢 LOW';
  };

  for (const r of results) {
    const loc = r.locations?.[0]?.physicalLocation;
    if (!loc) continue;

    const path = loc.artifactLocation?.uri;
    const line = loc.region?.startLine || 1;
    if (!path) continue;

    const ruleId = r.ruleId || "Vulnerability";
    const message = r.message?.text || "Dependency vulnerability found";
    const severity = getSeverity(r);
    const rule = ruleIndex[ruleId];
    const helpUri = rule?.helpUri || '';

    const body = `🔓 **Dependency Vulnerability** ${severity}

**CVE:** \`${ruleId}\`  
**Details:** ${message}
${helpUri ? `\n📚 [Vulnerability details](${helpUri})` : ''}

🔧 Update the affected dependency to a patched version.`;

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