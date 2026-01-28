const fs = require('fs');

module.exports = async ({ github, context }) => {
  const sarif = JSON.parse(fs.readFileSync('results.sarif', 'utf8'));
  const results = sarif.runs?.[0]?.results || [];

  if (results.length === 0) return;

  const { owner, repo } = context.repo;
  const pull_number = context.issue.number;

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

    let fileLine = 0;     // actual file line (post-PR)
    let hunkStart = 0;    // +c from @@

    for (const l of lines) {
      position++;

      if (l.startsWith('@@')) {
        const match = /\+(\d+)/.exec(l);
        if (match) {
          fileLine = parseInt(match[1], 10) - 1;
          hunkStart = fileLine;
        }
        continue;
      }

      // Ignore headers
      if (l.startsWith('+++') || l.startsWith('---')) continue;

      // Only advance file line if not a pure deletion
      if (!l.startsWith('-')) {
        fileLine++;
      }

      // Map REAL file line → position
      if (!positionMap[file.filename]) positionMap[file.filename] = {};
      positionMap[file.filename][fileLine] = position;
    }
  }

  for (const r of results) {
    const loc = r.locations?.[0]?.physicalLocation;
    if (!loc) continue;

    const path = loc.artifactLocation.uri;
    const line = loc.region.startLine;

    const rule = r.ruleId || "Secret detected";
    const message = r.message?.text || "Potential secret found";

    const body = `🔐 **Secret detected by Gitleaks**

**Rule:** ${rule}  
**Details:** ${message}

❌ Remove and rotate this secret.`;

    try {
      if (newFiles.has(path)) {
        // For new files
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
        // For modified files
        const pos = positionMap[path]?.[line];
        if (!pos) continue;

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
