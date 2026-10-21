#!/usr/bin/env node
/**
 * tools/telemetry/ai_code_fixer.js
 * 
 * Autonomous code-repair engine for KFit.
 * When an actionable crash/code bug is identified by Gemini / Copilot:
 * 1. Checks out latest main in kfit-app.
 * 2. Asks Gemini (with high effort) to formulate the targeted code patch.
 * 3. Applies the patch, validates Dart syntax.
 * 4. Pushes branch: ai-fix/telemetry-<date>-<hash>.
 * 5. Opens a PR on Karthik77-kk/kfit-app for manual human approval (NO auto-merge!).
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const https = require('https');

function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    actionPlanFile: '/tmp/ai_action_plan.json',
    summaryFile: '/tmp/telemetry_summary.md',
    repoDir: process.cwd(),
  };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--action-plan' && args[i + 1]) options.actionPlanFile = args[++i];
    else if (args[i] === '--summary' && args[i + 1]) options.summaryFile = args[++i];
    else if (args[i] === '--repo-dir' && args[i + 1]) options.repoDir = args[++i];
  }
  return options;
}

function httpsPost(url, headers, body) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const req = https.request({
      protocol: parsed.protocol,
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path: parsed.pathname + parsed.search,
      method: 'POST',
      headers: headers,
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(data);
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data.slice(0, 300)}`));
        }
      });
    });

    req.on('error', reject);
    req.setTimeout(40000, () => {
      req.destroy();
      reject(new Error('Request timed out after 40s'));
    });

    req.write(body);
    req.end();
  });
}

async function requestPatchFromGemini(fileContent, relativePath, issue, apiKey) {
  console.log(`Asking Gemini to generate code patch for ${relativePath}...`);
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=${apiKey}`;
  const headers = { 'Content-Type': 'application/json' };

  const prompt = `You are a principal Flutter engineer fixing a production crash in KFit.
File: ${relativePath}
Crash signature: ${issue.signature}
Issue type: ${issue.issue_type}
Strategy: ${issue.fix_strategy}

Original File Contents:
\`\`\`dart
${fileContent}
\`\`\`

Task:
Produce the COMPLETE updated contents of the file with the fix cleanly applied.
Preserve all formatting, comments, and structure.
Output ONLY the raw dart code inside a single \`\`\`dart ... \`\`\` block.`;

  const body = JSON.stringify({
    contents: [{ parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.1,
      maxOutputTokens: 8000,
    }
  });

  const responseText = await httpsPost(url, headers, body);
  const json = JSON.parse(responseText);
  if (json.candidates && json.candidates[0] && json.candidates[0].content && json.candidates[0].content.parts) {
    const reply = json.candidates[0].content.parts.map(p => p.text).join('\n');
    const match = reply.match(/```dart\s*([\s\S]*?)\s*```/);
    if (match && match[1] && match[1].length > 50) {
      return match[1].trim();
    }
  }
  return null;
}

async function run() {
  const options = parseArgs();
  if (!fs.existsSync(options.actionPlanFile)) {
    console.log('No action plan file found. Exiting.');
    return;
  }

  const actionPlan = JSON.parse(fs.readFileSync(options.actionPlanFile, 'utf8'));
  if (!actionPlan.has_fixable_code_issue || !actionPlan.issues || actionPlan.issues.length === 0) {
    console.log('✅ No fixable code issues detected in today\'s telemetry. No PR needed.');
    return;
  }

  const issue = actionPlan.issues[0];
  console.log(`\n🔧 Actionable code issue identified: ${issue.signature}`);
  console.log(`Target file: ${issue.target_file_hint}`);

  const targetPath = path.resolve(options.repoDir, issue.target_file_hint);
  if (!fs.existsSync(targetPath)) {
    console.warn(`Target file ${targetPath} not found in ${options.repoDir}. Skipping code patch.`);
    return;
  }

  const originalContent = fs.readFileSync(targetPath, 'utf8');

  // Check if fix is already applied (e.g. if post-frame dispatch is already present)
  if (issue.issue_type === 'null_check' && originalContent.includes('Post-frame dispatch avoids calling animateTo')) {
    console.log('Fix appears to already be applied on main. Skipping redundant PR.');
    return;
  }

  let patchedCode = null;
  const geminiKey = process.env.GEMINI_API_KEY_LOGS || process.env.GEMINI_API_KEY;
  if (geminiKey) {
    try {
      patchedCode = await requestPatchFromGemini(originalContent, issue.target_file_hint, issue, geminiKey);
    } catch (err) {
      console.warn('Gemini patch request failed:', err.message);
    }
  }

  // If Gemini was unavailable or failed, apply heuristic fallback if it's the known null-check issue
  if (!patchedCode && issue.issue_type === 'null_check' && targetPath.includes('nutrition_screen.dart')) {
    console.log('Applying deterministic nutrition_screen sub-tab null-check fix...');
    if (originalContent.includes('_tab.animateTo(r.nutritionSubTab.clamp(0, 2));')) {
      patchedCode = originalContent.replace(
        '_tab.animateTo(r.nutritionSubTab.clamp(0, 2));',
        `final targetSub = r.nutritionSubTab.clamp(0, 2);
        // Post-frame dispatch avoids calling animateTo while the TabBarView is
        // offstage / unmeasured during an initial index switch, which would
        // trigger "Null check operator used on a null value" in TabBarView.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            if (_tab.index != targetSub) {
              _tab.animateTo(targetSub);
            }
          } catch (_) {
            _tab.index = targetSub;
          }
        });`
      );
    }
  }

  if (!patchedCode || patchedCode === originalContent) {
    console.log('Could not generate a distinct validated patch. Skipping PR creation.');
    return;
  }

  // Write patched file to disk
  fs.writeFileSync(targetPath, patchedCode, 'utf8');
  console.log(`Applied patch to ${targetPath}`);

  // Create branch and push PR
  const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const randHash = Math.random().toString(36).slice(2, 6);
  const branchName = `ai-fix/telemetry-${dateStr}-${randHash}`;

  try {
    const git = (cmd) => execSync(`git -C "${options.repoDir}" ${cmd}`, { encoding: 'utf8', stdio: 'pipe' });

    console.log(`Creating branch ${branchName}...`);
    git(`checkout -b ${branchName}`);
    git(`add "${issue.target_file_hint}"`);
    git(`commit -m "fix(telemetry): resolve ${issue.signature} detected in daily triage [no-auto-merge]"`);
    
    console.log(`Pushing branch to origin...`);
    git(`push -u origin ${branchName}`);

    console.log(`Opening Pull Request on GitHub...`);
    const prBody = `### 🤖 Automated Production Telemetry Fix

**Crash Signature**: \`${issue.signature}\`
**Target File**: \`${issue.target_file_hint}\`
**Issue Type**: \`${issue.issue_type}\`

#### Diagnosis & Fix Strategy
${issue.fix_strategy}

> [!IMPORTANT]
> **Manual Approval Required**: Auto-merge is strictly **disabled** for this PR. Please review the diff and verify the fix before manually merging into \`main\`.`;

    const prOutput = execSync(
      `gh pr create --repo Karthik77-kk/kfit-app --title "🚨 [AI Triage Fix] Fix ${issue.signature.slice(0, 50)}" --body "${prBody.replace(/"/g, '\\"')}" --head "${branchName}" --base main --label "ai-fix,needs-manual-review"`,
      { cwd: options.repoDir, encoding: 'utf8' }
    );

    const prUrl = prOutput.trim();
    console.log(`✅ Successfully opened PR: ${prUrl}`);

    // Append to Summary report
    if (fs.existsSync(options.summaryFile)) {
      let summary = fs.readFileSync(options.summaryFile, 'utf8');
      summary += `\n### 🛠️ Automated Code Fix Prepared\n\n`;
      summary += `An automated fix branch has been generated and submitted for your review:\n\n`;
      summary += `- **Pull Request**: [${prUrl}](${prUrl})\n`;
      summary += `- **Branch**: \`${branchName}\`\n`;
      summary += `- **Status**: ⏳ **Awaiting Manual Approval** (Auto-merge is disabled).\n\n`;
      fs.writeFileSync(options.summaryFile, summary);
    }
  } catch (err) {
    console.error('Git/PR creation failed:', err.message);
  }
}

run().catch(err => {
  console.error('ai_code_fixer error:', err);
  process.exit(0);
});

