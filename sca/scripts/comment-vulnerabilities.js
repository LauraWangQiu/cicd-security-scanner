const fs = require('fs');

module.exports = async ({ github, context }) => {
  const sarif = JSON.parse(fs.readFileSync('results.sarif', 'utf8'));
  const results = sarif.runs?.[0]?.results || [];
  const rules = sarif.runs?.[0]?.tool?.driver?.rules || [];

  if (results.length === 0) return;

  const { owner, repo } = context.repo;
  const pull_number = context.issue.number;

  // Build rule index for severity lookup
  const ruleIndex = {};
  for (const rule of rules) {
    ruleIndex[rule.id] = rule;
  }

  // Extract severity from SARIF (Trivy stores it in rule properties or message)
  const getSeverity = (result) => {
    // Try rule properties first
    const rule = ruleIndex[result.ruleId];
    if (rule?.properties?.['security-severity']) {
      const score = parseFloat(rule.properties['security-severity']);
      if (score >= 9.0) return 'CRITICAL';
      if (score >= 7.0) return 'HIGH';
      if (score >= 4.0) return 'MEDIUM';
      return 'LOW';
    }
    // Try message text
    const msg = result.message?.text || '';
    const severityMatch = msg.match(/Severity:\s*(CRITICAL|HIGH|MEDIUM|LOW)/i);
    if (severityMatch) return severityMatch[1].toUpperCase();
    // Fallback
    return 'UNKNOWN';
  };

  // Group vulnerabilities by package
  const vulnsByPackage = {};
  for (const r of results) {
    const ruleId = r.ruleId || 'Unknown';
    const message = r.message?.text || 'Vulnerability detected';
    const severity = getSeverity(r);
    
    // Extract package name from message
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
      severity
    });
  }

  // Severity order for sorting (lower = more critical)
  const severityOrder = { 'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3, 'UNKNOWN': 4 };

  // Get highest severity for a package
  const getHighestSeverity = (vulns) => {
    return vulns.reduce((highest, v) => {
      const currentOrder = severityOrder[v.severity] ?? 5;
      const highestOrder = severityOrder[highest] ?? 5;
      return currentOrder < highestOrder ? v.severity : highest;
    }, 'UNKNOWN');
  };

  // Sort packages: first by severity (critical first), then alphabetically
  const sortedPackages = Object.entries(vulnsByPackage).sort((a, b) => {
    const [pkgA, vulnsA] = a;
    const [pkgB, vulnsB] = b;
    
    const sevA = severityOrder[getHighestSeverity(vulnsA)] ?? 5;
    const sevB = severityOrder[getHighestSeverity(vulnsB)] ?? 5;
    
    if (sevA !== sevB) return sevA - sevB;
    return pkgA.toLowerCase().localeCompare(pkgB.toLowerCase());
  });

  // Build summary comment
  let body = `## 🔓 Dependency Vulnerabilities Found\n\n`;
  body += `**Total:** ${results.length} vulnerability(ies)\n\n`;
  body += `| Package | Vulnerabilities | Severity |\n`;
  body += `|---------|-----------------|----------|\n`;

  for (const [pkg, vulns] of sortedPackages) {
    const severities = [...new Set(vulns.map(v => v.severity))].join(', ');
    body += `| \`${pkg}\` | ${vulns.length} | ${severities} |\n`;
  }

  body += `\n### Details\n\n`;

  for (const [pkg, vulns] of sortedPackages) {
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
