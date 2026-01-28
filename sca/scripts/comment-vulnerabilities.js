const fs = require('fs');

module.exports = async ({ github, context }) => {
  const sarif = JSON.parse(fs.readFileSync('results.sarif', 'utf8'));
  const results = sarif.runs?.[0]?.results || [];

  if (results.length === 0) return;

  const { owner, repo } = context.repo;
  const pull_number = context.issue.number;

  // Group vulnerabilities by package
  const vulnsByPackage = {};
  for (const r of results) {
    const ruleId = r.ruleId || 'Unknown';
    const message = r.message?.text || 'Vulnerability detected';
    
    // Extract package name from rule or message
    const packageMatch = message.match(/Package:\s*(\S+)/i) || 
                         message.match(/in\s+(\S+)/i) ||
                         [null, ruleId];
    const packageName = packageMatch[1] || ruleId;

    if (!vulnsByPackage[packageName]) {
      vulnsByPackage[packageName] = [];
    }
    vulnsByPackage[packageName].push({
      ruleId,
      message,
      severity: r.level || 'warning'
    });
  }

  // Build summary comment
  let body = `## 🔓 Dependency Vulnerabilities Found\n\n`;
  body += `**Total:** ${results.length} vulnerability(ies)\n\n`;
  body += `| Package | Vulnerabilities | Severity |\n`;
  body += `|---------|-----------------|----------|\n`;

  for (const [pkg, vulns] of Object.entries(vulnsByPackage)) {
    const severities = [...new Set(vulns.map(v => v.severity))].join(', ');
    body += `| \`${pkg}\` | ${vulns.length} | ${severities} |\n`;
  }

  body += `\n### Details\n\n`;

  for (const [pkg, vulns] of Object.entries(vulnsByPackage)) {
    body += `<details>\n<summary><strong>${pkg}</strong> (${vulns.length})</summary>\n\n`;
    for (const v of vulns) {
      body += `- **${v.ruleId}**: ${v.message}\n`;
    }
    body += `\n</details>\n\n`;
  }

  body += `\n---\n⚠️ **Action required:** Update vulnerable dependencies before merging.`;

  try {
    await github.rest.issues.createComment({
      owner,
      repo,
      issue_number: pull_number,
      body
    });
    console.log('Posted vulnerability summary comment');
  } catch (e) {
    console.log(`Failed to post comment: ${e.message}`);
  }
};
