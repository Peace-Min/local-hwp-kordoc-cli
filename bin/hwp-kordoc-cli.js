#!/usr/bin/env node

import { mkdirSync, statSync, writeFileSync } from "fs";
import { basename, dirname, resolve } from "path";
import {
  parse,
  detectFormat,
  VERSION
} from "../vendor/kordoc/dist/index.js";
import { readFileSync } from "fs";

const USAGE = `
hwp-kordoc <files...> [options]

Convert HWP/HWPX/HWPML files to Markdown or JSON using the
vendored kordoc parser runtime. This wrapper is intended for local Hancom
document extraction and intentionally does not expose MCP, watch, setup, patch,
PDF formula OCR, or form-fill commands.

Options:
  -o, --output <path>     Output file path. Only valid with one input file.
  -d, --out-dir <dir>     Output directory for one or more input files.
  -f, --format <type>     markdown or json. Default: markdown.
  -p, --pages <range>     Page/section range supported by kordoc, e.g. 1-3.
  --silent                Hide progress messages.
  -h, --help              Show this help.
  -v, --version           Show vendored kordoc version.

Examples:
  hwp-kordoc report.hwpx -o report.md
  hwp-kordoc drm-report.hwp --format json -o report.json
  hwp-kordoc *.hwp --out-dir out
`;

function parseArgs(argv) {
  const files = [];
  const opts = {
    format: "markdown",
    output: undefined,
    outDir: undefined,
    pages: undefined,
    silent: false,
    help: false,
    version: false
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const next = () => {
      if (i + 1 >= argv.length) throw new Error(`Missing value for ${arg}`);
      return argv[++i];
    };

    if (arg === "-h" || arg === "--help") opts.help = true;
    else if (arg === "-v" || arg === "--version") opts.version = true;
    else if (arg === "-o" || arg === "--output") opts.output = next();
    else if (arg === "-d" || arg === "--out-dir") opts.outDir = next();
    else if (arg === "-f" || arg === "--format") opts.format = next();
    else if (arg === "-p" || arg === "--pages") opts.pages = next();
    else if (arg === "--silent") opts.silent = true;
    else if (arg.startsWith("-")) throw new Error(`Unknown option: ${arg}`);
    else files.push(arg);
  }

  return { files, opts };
}

function outputPathFor(filePath, opts) {
  const outExt = opts.format === "json" ? ".json" : ".md";
  const fileName = basename(filePath).replace(/\.[^.]+$/, outExt);
  return resolve(opts.outDir, fileName);
}

function writeImages(result, baseDir, silent) {
  if (!result.images?.length) return;

  const imageDir = resolve(baseDir, "images");
  mkdirSync(imageDir, { recursive: true });

  for (const image of result.images) {
    writeFileSync(resolve(imageDir, image.filename), image.data);
  }

  if (!silent) {
    process.stderr.write(`[hwp-kordoc] wrote ${result.images.length} image(s): ${imageDir}\n`);
  }
}

function toArrayBuffer(buffer) {
  return buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength);
}

async function convertOne(filePath, index, total, opts) {
  const absPath = resolve(filePath);
  const fileName = basename(absPath);
  const filePrefix = total > 1 ? `[${index + 1}/${total}] ` : "";

  const fileSize = statSync(absPath).size;
  if (fileSize > 500 * 1024 * 1024) {
    throw new Error(`${fileName} is too large (${(fileSize / 1024 / 1024).toFixed(1)}MB)`);
  }

  const buffer = readFileSync(absPath);
  const arrayBuffer = toArrayBuffer(buffer);
  const format = detectFormat(arrayBuffer);

  if (!opts.silent) {
    process.stderr.write(`[hwp-kordoc] ${filePrefix}${fileName} (${format}) ...`);
  }

  const parseOptions = { filePath: absPath };
  if (opts.pages) parseOptions.pages = opts.pages;

  const result = await parse(arrayBuffer, parseOptions);
  if (!result.success) {
    if (!opts.silent) process.stderr.write(" FAIL\n");
    throw new Error(result.error ?? "parse failed");
  }

  if (!opts.silent) process.stderr.write(" OK\n");

  let markdown = result.markdown;
  if (opts.outDir && result.images?.length) {
    markdown = markdown.replace(/!\[image\]\(image_/g, "![image](images/image_");
  }

  const output = opts.format === "json"
    ? JSON.stringify(result, (_key, value) => {
      if (value instanceof Uint8Array) return Buffer.from(value).toString("base64");
      return value;
    }, 2)
    : markdown;

  if (opts.output && total === 1) {
    const outPath = resolve(opts.output);
    mkdirSync(dirname(outPath), { recursive: true });
    writeFileSync(outPath, output, "utf-8");
    writeImages(result, dirname(outPath), opts.silent);
    return;
  }

  if (opts.outDir) {
    mkdirSync(opts.outDir, { recursive: true });
    const outPath = outputPathFor(absPath, opts);
    writeFileSync(outPath, output, "utf-8");
    writeImages(result, opts.outDir, opts.silent);
    return;
  }

  process.stdout.write(output + "\n");
}

async function main() {
  const { files, opts } = parseArgs(process.argv.slice(2));

  if (opts.help) {
    process.stdout.write(USAGE.trimStart());
    return;
  }

  if (opts.version) {
    process.stdout.write(`${VERSION}\n`);
    return;
  }

  if (!["markdown", "json"].includes(opts.format)) {
    throw new Error(`Unsupported format: ${opts.format}. Use markdown or json.`);
  }

  if (opts.output && files.length !== 1) {
    throw new Error("--output can only be used with exactly one input file.");
  }

  if (files.length === 0) {
    process.stdout.write(USAGE.trimStart());
    process.exitCode = 1;
    return;
  }

  for (let i = 0; i < files.length; i++) {
    try {
      await convertOne(files[i], i, files.length, opts);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      process.stderr.write(`[hwp-kordoc] ERROR: ${basename(files[i])}: ${message}\n`);
      process.exitCode = 1;
    }
  }
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`[hwp-kordoc] ERROR: ${message}\n`);
  process.exit(1);
});
