#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const defaultSettingsPath = path.resolve(__dirname, "..", "..", ".vscode", "settings.json");
const settingsPath = path.resolve(process.argv[2] ?? defaultSettingsPath);

function sortJson(value) {
    if (Array.isArray(value)) {
        return value.map(sortJson);
    }

    if (value !== null && typeof value === "object") {
        return Object.fromEntries(
            Object.entries(value)
                .sort(([left], [right]) => left.localeCompare(right))
                .map(([key, nestedValue]) => [key, sortJson(nestedValue)])
        );
    }

    return value;
}

if (process.argv.includes("--help") || process.argv.includes("-h")) {
    console.log("Usage: node llm-prompts/scripts/sort-settings-json.js [path/to/settings.json]");
    process.exit(0);
}

const originalJson = fs.readFileSync(settingsPath, "utf8");
const sortedJson = `${JSON.stringify(sortJson(JSON.parse(originalJson)), null, 4)}\n`;

if (sortedJson !== originalJson) {
    fs.writeFileSync(settingsPath, sortedJson);
    console.log(`Sorted ${settingsPath}`);
} else {
    console.log(`Already sorted: ${settingsPath}`);
}