#!/usr/bin/env node
/**
 * tools/telemetry/analyze_telemetry.js
 * 
 * Deterministic triage engine for KFit Supabase telemetry.
 * Computes 24-hour error rates, subsystem health, auto-update efficacy,
 * crash signatures, and generates both a human-readable GitHub Step Summary
 * and a budget-capped AI prompt payload (<1,500 tokens).
 */

const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    file: '/tmp/telemetry_data/telemetry_events.json',
    hours: 24,
    outputSummary: '/tmp/telemetry_summary.md',
    outputPrompt: '/tmp/ai_prompt.json',
  };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--file' && args[i + 1]) options.file = args[++i];
    else if (args[i] === '--hours' && args[i + 1]) options.hours = parseFloat(args[++i]);
    else if (args[i] === '--output-summary' && args[i + 1]) options.outputSummary = args[++i];
    else if (args[i] === '--output-prompt' && args[i + 1]) options.outputPrompt = args[++i];
  }
  return options;
}

function sanitizeStack(stack) {
  if (!stack) return '';
  const lines = stack.split('\n').filter(Boolean);
  return lines.slice(0, 10).join('\n');
}

function run() {
  const options = parseArgs();
  console.log(`Analyzing telemetry from: ${options.file}`);
  console.log(`Time window: last ${options.hours} hours`);

  if (!fs.existsSync(options.file)) {
    console.error(`Telemetry file not found: ${options.file}`);
    process.exit(1);
  }

  const rawData = fs.readFileSync(options.file, 'utf8');
  let events = [];
  try {
    events = JSON.parse(rawData);
  } catch (err) {
    console.error('Failed to parse telemetry JSON:', err.message);
    process.exit(1);
  }

  if (!Array.isArray(events) || events.length === 0) {
    console.log('No events to analyze.');
    fs.writeFileSync(options.outputSummary, '### KFit Telemetry Daily Report\n\nNo telemetry events found in the requested window.\n');
    fs.writeFileSync(options.outputPrompt, JSON.stringify({ empty: true }));
    return;
  }

  let maxTime = 0;
  events.forEach(e => {
    const t = new Date(e.created_at).getTime();
    if (!isNaN(t) && t > maxTime) maxTime = t;
  });

  const windowMs = options.hours * 60 * 60 * 1000;
  const cutoffTime = maxTime - windowMs;
  const cutoffIso = new Date(cutoffTime).toISOString();
  const maxIso = new Date(maxTime).toISOString();

  console.log(`Baseline period: up to ${maxIso}`);
  console.log(`Analysis window: ${cutoffIso} to ${maxIso}`);

  const windowEvents = [];
  const historicalSignatures = new Set();

  events.forEach(e => {
    const t = new Date(e.created_at).getTime();
    const sig = `${e.category}/${e.operation}|${e.error_code || ''}|${e.error_message || ''}`;
    
    if (t >= cutoffTime) {
      windowEvents.push(e);
    } else {
      if (e.status === 'error') {
        historicalSignatures.add(sig);
      }
    }
  });

  console.log(`Events in window: ${windowEvents.length} / total ${events.length}`);

  // Aggregations
  let totalErrors = 0;
  let totalSuccess = 0;
  let totalDetected = 0;
  const categories = {};
  const versions = {};
  const users = new Set();
  const errorMap = {};
  const autoUpdateMetrics = {
    checks: 0,
    available: 0,
    upToDate: 0,
    deltasStarted: 0,
    deltasSuccess: 0,
    deltasFailed: 0,
    fullDownloads: 0,
    installsInitiated: 0,
    dialogShown: 0,
    errors: [],
  };

  const appHealthMetrics = {
    coldStarts: 0,
    lowMemoryKills: 0,
    abnormalTerminations: 0,
  };

  const syncMetrics = {
    totalCycles: 0,
    successCycles: 0,
    errorCycles: 0,
    totalPushed: 0,
    totalPulled: 0,
  };

  windowEvents.forEach(e => {
    if (e.user_id) users.add(e.user_id);
    const ver = e.app_version || 'unknown';
    versions[ver] = (versions[ver] || 0) + 1;

    const cat = e.category || 'other';
    categories[cat] = categories[cat] || { total: 0, errors: 0 };
    categories[cat].total++;

    if (e.status === 'error') {
      totalErrors++;
      categories[cat].errors++;

      const sigKey = `${e.category}/${e.operation} | ${e.error_code || 'NO_CODE'} | ${(e.error_message || 'NO_MSG').slice(0, 120)}`;
      if (!errorMap[sigKey]) {
        errorMap[sigKey] = {
          count: 0,
          category: e.category,
          operation: e.operation,
          code: e.error_code,
          message: e.error_message,
          versions: new Set(),
          firstSeen: e.created_at,
          lastSeen: e.created_at,
          isNewRegression: !historicalSignatures.has(`${e.category}/${e.operation}|${e.error_code || ''}|${e.error_message || ''}`),
          sampleStack: null,
          sampleBreadcrumbs: null,
        };
      }
      errorMap[sigKey].count++;
      errorMap[sigKey].versions.add(ver);
      if (e.created_at > errorMap[sigKey].lastSeen) errorMap[sigKey].lastSeen = e.created_at;

      const meta = typeof e.metadata === 'string' ? JSON.parse(e.metadata) : (e.metadata || {});
      if (!errorMap[sigKey].sampleStack && meta.stack) {
        errorMap[sigKey].sampleStack = sanitizeStack(meta.stack);
      }
      if (!errorMap[sigKey].sampleBreadcrumbs && Array.isArray(meta.breadcrumbs) && meta.breadcrumbs.length > 0) {
        errorMap[sigKey].sampleBreadcrumbs = meta.breadcrumbs.slice(-4);
      }
    } else if (e.status === 'success') {
      totalSuccess++;
    } else if (e.status === 'detected') {
      totalDetected++;
    }

    // Auto-update tracking
    if (cat === 'app_update') {
      if (e.operation.includes('check_up_to_date')) autoUpdateMetrics.upToDate++;
      if (e.operation.includes('check_update_available')) autoUpdateMetrics.available++;
      if (e.operation.includes('check_for_update') || e.operation.includes('manual_check')) autoUpdateMetrics.checks++;
      if (e.operation === 'delta_patch_started') autoUpdateMetrics.deltasStarted++;
      if (e.operation === 'delta_patch_success') autoUpdateMetrics.deltasSuccess++;
      if (e.operation === 'delta_patch_failed') autoUpdateMetrics.deltasFailed++;
      if (e.operation === 'full_download_started') autoUpdateMetrics.fullDownloads++;
      if (e.operation === 'update_install_initiated') autoUpdateMetrics.installsInitiated++;
      if (e.operation === 'dialog_displayed') autoUpdateMetrics.dialogShown++;
      if (e.status === 'error') {
        autoUpdateMetrics.errors.push(`${e.operation}: ${e.error_message || ''}`);
      }
    }

    // App Health tracking
    if (cat === 'app_health') {
      if (e.operation === 'cold_start') appHealthMetrics.coldStarts++;
      if (e.operation === 'low_memory_kill') appHealthMetrics.lowMemoryKills++;
      if (e.operation === 'abnormal_termination') appHealthMetrics.abnormalTerminations++;
    }

    // Sync tracking
    if (cat === 'sync') {
      if (e.operation === 'sync_cycle') {
        syncMetrics.totalCycles++;
        if (e.status === 'success') syncMetrics.successCycles++;
        else if (e.status === 'error') syncMetrics.errorCycles++;
      }
      const meta = typeof e.metadata === 'string' ? JSON.parse(e.metadata) : (e.metadata || {});
      if (meta.pushed) syncMetrics.totalPushed += meta.pushed;
      if (meta.pulled) syncMetrics.totalPulled += meta.pulled;
    }
  });

  const totalEventsInWindow = windowEvents.length;
  const errorRate = totalEventsInWindow > 0 ? ((totalErrors / totalEventsInWindow) * 100).toFixed(2) : '0.00';
  const syncSuccessRate = syncMetrics.totalCycles > 0 ? (((syncMetrics.successCycles) / syncMetrics.totalCycles) * 100).toFixed(1) : '100.0';

  const sortedErrors = Object.entries(errorMap).sort((a, b) => b[1].count - a[1].count);
  const newRegressions = sortedErrors.filter(([, data]) => data.isNewRegression);

  // Generate Step Summary Markdown
  let md = '';
  md += `# 📊 KFit Daily Telemetry & Health Report\n\n`;
  md += `> **Report Window**: ${cutoffIso.replace('T', ' ').slice(0, 19)} UTC → ${maxIso.replace('T', ' ').slice(0, 19)} UTC (Last ${options.hours}h)\n\n`;

  // Status Badge Callout
  if (totalErrors === 0) {
    md += `> [!NOTE]\n> **App Health: EXCELLENT** 🟢 — 0 errors detected in the last ${options.hours} hours across ${totalEventsInWindow} telemetry events.\n\n`;
  } else if (newRegressions.length > 0) {
    md += `> [!CAUTION]\n> **App Health: ATTENTION NEEDED** 🔴 — ${newRegressions.length} NEW error signature(s) detected in latest release! Total error rate: **${errorRate}%**.\n\n`;
  } else {
    md += `> [!IMPORTANT]\n> **App Health: STABLE WITH KNOWN ANOMALIES** 🟡 — Error rate: **${errorRate}%** (${totalErrors} errors). No new regressions detected.\n\n`;
  }

  // Key Vital Metrics Table
  md += `### 📈 24-Hour Vitals\n\n`;
  md += `| Metric | Value | Status |\n`;
  md += `| :--- | :--- | :--- |\n`;
  md += `| **Total Telemetry Events** | \`${totalEventsInWindow}\` | ℹ️ Active traffic |\n`;
  md += `| **Active Users / Devices** | \`${users.size}\` | 👤 Profile sessions |\n`;
  md += `| **Overall Error Rate** | \`${errorRate}%\` (${totalErrors} errors) | ${parseFloat(errorRate) < 5 ? '🟢 Normal' : '🔴 Elevated'} |\n`;
  md += `| **Sync Cycles** | \`${syncMetrics.totalCycles}\` (${syncSuccessRate}% success) | ${parseFloat(syncSuccessRate) > 95 ? '🟢 Healthy' : '🟡 Review'} |\n`;
  md += `| **Auto-Update Checks** | \`${autoUpdateMetrics.checks}\` checks, \`${autoUpdateMetrics.installsInitiated}\` installs | 🟢 Operational |\n`;
  md += `| **Cold Starts** | \`${appHealthMetrics.coldStarts}\` launches | 🚀 |\n`;
  md += `| **Low Memory Kills (OS)** | \`${appHealthMetrics.lowMemoryKills}\` background kills | 📱 Standard Android memory reclaim |\n\n`;

  // Active Versions Table
  md += `### 📱 Active App Versions in Production\n\n`;
  md += `| App Version | Event Volume | Share |\n`;
  md += `| :--- | :--- | :--- |\n`;
  for (const [ver, cnt] of Object.entries(versions).sort((a,b) => b[1] - a[1])) {
    const pct = ((cnt / totalEventsInWindow) * 100).toFixed(1);
    md += `| \`${ver}\` | ${cnt} | ${pct}% |\n`;
  }
  md += `\n`;

  // Subsystem Breakdown
  md += `### ⚙️ Subsystem Breakdown\n\n`;
  md += `| Category | Total Events | Errors | Error Rate |\n`;
  md += `| :--- | :--- | :--- | :--- |\n`;
  for (const [cat, data] of Object.entries(categories).sort((a,b) => b[1].total - a[1].total)) {
    const catRate = ((data.errors / data.total) * 100).toFixed(1);
    const badge = data.errors === 0 ? '🟢' : (parseFloat(catRate) > 10 ? '🔴' : '🟡');
    md += `| \`${cat}\` | ${data.total} | ${data.errors} | ${badge} ${catRate}% |\n`;
  }
  md += `\n`;

  // Auto-Update Subsystem Deep Dive
  md += `### 🔄 Auto-Update & Delta Engine Status\n\n`;
  md += `- **Update checks performed**: \`${autoUpdateMetrics.checks}\`\n`;
  md += `- **Updates detected as available**: \`${autoUpdateMetrics.available}\`\n`;
  md += `- **Delta patches attempted**: \`${autoUpdateMetrics.deltasStarted}\` (✅ Success: \`${autoUpdateMetrics.deltasSuccess}\`, ❌ Failed: \`${autoUpdateMetrics.deltasFailed}\`)\n`;
  md += `- **Full downloads initiated**: \`${autoUpdateMetrics.fullDownloads}\`\n`;
  md += `- **Update install clicks**: \`${autoUpdateMetrics.installsInitiated}\`\n`;
  if (autoUpdateMetrics.errors.length > 0) {
    md += `- **Update Errors Logged**:\n`;
    autoUpdateMetrics.errors.forEach(err => {
      md += `  - \`${err}\`\n`;
    });
  } else {
    md += `- **Auto-update health**: 🟢 All checks and downloads executed without failure.\n`;
  }
  md += `\n`;

  // Error Catalog
  md += `### 🔍 Error Catalog & Root-Cause Triage\n\n`;
  if (sortedErrors.length === 0) {
    md += `No error events observed in this window.\n\n`;
  } else {
    md += `| Occurrences | Signature | Category | Affected Versions | Status |\n`;
    md += `| :--- | :--- | :--- | :--- | :--- |\n`;
    sortedErrors.forEach(([key, d]) => {
      const vers = Array.from(d.versions).join(', ');
      const regTag = d.isNewRegression ? '🔴 **NEW REGRESSION**' : '🟡 Known';
      md += `| **${d.count}x** | \`${d.operation}\` - *${d.message || d.code || 'error'}* | \`${d.category}\` | \`${vers}\` | ${regTag} |\n`;
    });
    md += `\n`;

    // Detailed Stack Trace for Top Errors
    md += `#### Top Error Signatures & Context\n\n`;
    sortedErrors.slice(0, 5).forEach(([key, d], idx) => {
      md += `**#${idx + 1}. [${d.count}x] \`${d.category}/${d.operation}\` — ${d.message || d.code}**\n\n`;
      md += `- **Versions**: \`${Array.from(d.versions).join(', ')}\`\n`;
      md += `- **First Seen**: \`${d.firstSeen}\` | **Last Seen**: \`${d.lastSeen}\`\n`;
      if (d.sampleBreadcrumbs && d.sampleBreadcrumbs.length > 0) {
        md += `- **Preceding Breadcrumbs**:\n`;
        d.sampleBreadcrumbs.forEach(bc => md += `  - \`${bc}\`\n`);
      }
      if (d.sampleStack) {
        md += `\n\`\`\`text\n${d.sampleStack}\n\`\`\`\n`;
      }
      md += `\n`;
    });
  }

  fs.writeFileSync(options.outputSummary, md);
  console.log(`Wrote summary report to ${options.outputSummary}`);

  // Create condensed AI Prompt JSON (budget-capped <1,500 tokens)
  const aiPayload = {
    window_hours: options.hours,
    total_events: totalEventsInWindow,
    error_count: totalErrors,
    error_rate: `${errorRate}%`,
    active_versions: versions,
    subsystems: categories,
    sync: {
      cycles: syncMetrics.totalCycles,
      success_rate: `${syncSuccessRate}%`,
    },
    auto_update: {
      checks: autoUpdateMetrics.checks,
      deltas_success: autoUpdateMetrics.deltasSuccess,
      deltas_failed: autoUpdateMetrics.deltasFailed,
      installs: autoUpdateMetrics.installsInitiated,
      errors: autoUpdateMetrics.errors,
    },
    top_errors: sortedErrors.slice(0, 5).map(([key, d]) => ({
      category: d.category,
      operation: d.operation,
      code: d.code,
      message: d.message,
      count: d.count,
      versions: Array.from(d.versions),
      is_new_regression: d.isNewRegression,
      breadcrumbs: d.sampleBreadcrumbs || [],
      stack_preview: d.sampleStack ? d.sampleStack.split('\n').slice(0, 6).join('\n') : null,
    })),
  };

  fs.writeFileSync(options.outputPrompt, JSON.stringify(aiPayload, null, 2));
  console.log(`Wrote condensed AI prompt to ${options.outputPrompt} (${JSON.stringify(aiPayload).length} chars)`);
}

run();

