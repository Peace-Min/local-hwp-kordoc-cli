# Local HWP Kordoc CLI

This repository vendors only the parsing runtime from `kordoc` and exposes a
small local CLI for Hancom document extraction. It intentionally does not
include or expose the kordoc MCP server.

## Install

```powershell
npm.cmd install
```

PowerShell may block `npm.ps1` depending on execution policy, so `npm.cmd` is
used in the examples.

## Offline Bundle

For a closed-network PC, build an offline ZIP on an internet-connected Windows
PC:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-offline-bundle.ps1
```

The ZIP is created under `dist\offline\` and includes the app, `node_modules`,
an installer script, and a Node.js MSI unless `-SkipNodeDownload` is passed.

On the closed-network PC, extract the ZIP and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -InstallNode
```

See `README_OFFLINE.md` for the full offline workflow.

## Usage

```powershell
npm.cmd run hwp -- .\sample.hwpx -o .\sample.md
node .\bin\hwp-kordoc-cli.js .\sample.hwp --format json -o .\sample.json
node .\bin\hwp-kordoc-cli.js .\input\file.hwp --out-dir .\out
```

For DRM/distribution HWP/HWPX documents, kordoc's COM fallback requires:

- Windows
- locally installed Hancom Office/HWP
- a document that the current user can normally open
- a working `HWPFrame.HwpObject` COM registration

The fallback extracts page text through Hancom COM. It does not preserve full
layout/table structure in DRM fallback mode.

## Vendored Files

- `vendor/kordoc/dist/index.js`
- `vendor/kordoc/dist/chunk-JHKGZ5ZK.js`
- `vendor/kordoc/dist/chunk-AIQ3ISQU.js`
- `vendor/kordoc/LICENSE`
- `vendor/kordoc/NOTICE`

The wrapper uses `parse`, `detectFormat`, `VERSION`, and `toArrayBuffer` from
the vendored runtime.

## Runtime Dependencies

Required for this reduced HWP/HWPX CLI:

- `jszip`
- `@xmldom/xmldom`
- `cfb`
- `markdown-it`

Not included:

- `@modelcontextprotocol/sdk`, `zod`: only needed for kordoc MCP server
- `commander`: replaced by this repository's small argument parser
- `pdfjs-dist`: optional in upstream kordoc, not included here
- `puppeteer-core`, `sharp`, `onnxruntime-node`, `@huggingface/transformers`,
  `@hyzyla/pdfium`: optional upstream kordoc features, not required for basic
  HWP/HWPX conversion

## Source

Vendored runtime is derived from `kordoc` v3.1.1:

<https://github.com/chrisryugj/kordoc>
