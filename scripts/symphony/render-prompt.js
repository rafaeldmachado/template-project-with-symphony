#!/usr/bin/env node
'use strict';

// Renders WORKFLOW.md prompt template with issue data.
//
// Supports Liquid-like syntax:
//   {{ variable }}              — substitution
//   {{ array | join: ", " }}    — join filter
//   {% if condition %}          — conditional (truthiness or .size > 0)
//   {% for item in collection %}— loop
//   {% endif %} / {% endfor %}  — block terminators
//
// Usage:
//   node render-prompt.js \
//     --number 42 \
//     --title "Fix login bug" \
//     --body "Users can't log in when..." \
//     --labels "bug,agent" \
//     --blocked-by '[{"identifier":"#10","state":"OPEN"}]' \
//     --attempt ""

const fs = require('fs');
const path = require('path');

// ── Parse CLI arguments ──────────────────────────────
const args = {};
for (let i = 2; i < process.argv.length; i++) {
  const arg = process.argv[i];
  if (arg.startsWith('--') && i + 1 < process.argv.length) {
    args[arg.slice(2)] = process.argv[++i];
  }
}

// ── Read template from WORKFLOW.md ───────────────────
const rootDir = path.resolve(__dirname, '..', '..');
const workflowPath = path.join(rootDir, 'WORKFLOW.md');

let template = '';
try {
  const content = fs.readFileSync(workflowPath, 'utf8');
  const lines = content.split('\n');
  let dashCount = 0;
  let bodyStart = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      dashCount++;
      if (dashCount === 2) { bodyStart = i + 1; break; }
    }
  }
  if (bodyStart >= 0) {
    template = lines.slice(bodyStart).join('\n').trim();
  }
} catch (err) {
  process.stderr.write(`ERROR: [symphony] Cannot read ${workflowPath}: ${err.message}\n`);
  process.exit(1);
}

if (!template) {
  template = [
    `You are working on issue #${args.number}: ${args.title}`,
    '',
    args.body || '',
    '',
    'Read AGENTS.md for project rules and conventions.',
    'Run make check before committing.'
  ].join('\n');
}

// ── Build data context ───────────────────────────────
let blockedBy = [];
try {
  if (args['blocked-by']) blockedBy = JSON.parse(args['blocked-by']);
} catch (_) { /* ignore parse errors */ }

const data = {
  issue: {
    identifier: args.number || '',
    title: args.title || '',
    description: args.body || '',
    labels: args.labels ? args.labels.split(',').filter(Boolean) : [],
    blocked_by: blockedBy
  },
  attempt: args.attempt || null
};

// ── Template engine ──────────────────────────────────

function resolve(obj, dotPath) {
  return dotPath.split('.').reduce(
    (o, k) => (o != null && o[k] !== undefined ? o[k] : undefined),
    obj
  );
}

function isTruthy(val) {
  if (val == null || val === '' || val === false) return false;
  if (Array.isArray(val) && val.length === 0) return false;
  return true;
}

function evalCondition(expr, ctx) {
  // "issue.labels.size > 0" → array length check
  const sizeMatch = expr.match(/^(.+)\.size\s*>\s*0$/);
  if (sizeMatch) {
    const val = resolve(ctx, sizeMatch[1]);
    return Array.isArray(val) && val.length > 0;
  }
  // Simple truthiness: "attempt"
  return isTruthy(resolve(ctx, expr));
}

function applyFilter(value, filterExpr) {
  const joinMatch = filterExpr.match(/join:\s*"([^"]*)"/);
  if (joinMatch && Array.isArray(value)) {
    return value.join(joinMatch[1]);
  }
  return value;
}

function renderExpr(expr, ctx) {
  const parts = expr.split('|').map(s => s.trim());
  let value = resolve(ctx, parts[0]);
  if (value === undefined) return '';
  for (let i = 1; i < parts.length; i++) {
    value = applyFilter(value, parts[i]);
  }
  return String(value);
}

// ── Render ───────────────────────────────────────────
let output = template;

// 1. {% for item in collection %} ... {% endfor %}
output = output.replace(
  /\{%\s*for\s+(\w+)\s+in\s+([\w.]+)\s*%\}([\s\S]*?)\{%\s*endfor\s*%\}/g,
  (_, itemVar, collPath, body) => {
    const collection = resolve(data, collPath);
    if (!Array.isArray(collection) || collection.length === 0) return '';
    return collection.map(item => {
      return body.replace(/\{\{(.+?)\}\}/g, (__, innerExpr) => {
        const trimmed = innerExpr.trim();
        if (trimmed.startsWith(itemVar + '.')) {
          const field = trimmed.slice(itemVar.length + 1);
          const val = item[field];
          return val !== undefined ? String(val) : '';
        }
        return renderExpr(trimmed, data);
      });
    }).join('');
  }
);

// 2. {% if condition %} ... {% endif %} (non-nested, iterative)
let prev;
do {
  prev = output;
  output = output.replace(
    /\{%\s*if\s+(.+?)\s*%\}([\s\S]*?)\{%\s*endif\s*%\}/,
    (_, condition, body) => evalCondition(condition.trim(), data) ? body : ''
  );
} while (output !== prev);

// 3. {{ expression }} variables
output = output.replace(
  /\{\{(.+?)\}\}/g,
  (_, expr) => renderExpr(expr.trim(), data)
);

// 4. Clean up stray Liquid tags and excessive blank lines
output = output.replace(/^\{%.*%\}\s*$/gm, '');
output = output.replace(/\n{3,}/g, '\n\n');

process.stdout.write(output.trim() + '\n');
