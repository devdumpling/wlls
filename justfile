app := "bin/wlls"

# Build settings shared by every Odin invocation. flake.nix mirrors the egress
# size for release builds (without the development flags); src/app/conf.odin
# asserts it, so a build that forgets it fails to compile.
odin_defines := "-define:HTTP_EGRESS_BUFFER_SIZE=16384 -define:TINA_ASSERTS=true -define:WLLS_DEV=true"
odin_flags := "-collection:tempo=" + env_var("TEMPO_SRC") + " -thread-count:1 " + odin_defines
# C libraries the app binds with `foreign import`; the Nix shell exports both.
libs := '-extra-linker-flags:"-L' + env_var("CMARK_GFM_LIB") + ' -L' + env_var("SQLITE_LIB") + '"'

default:
    @just --list

generate:
    tempo generate src/views -runtime=tempo:runtime

# Format authored Odin files; generated views and vendored sources are excluded.
format:
    git ls-files --cached --others --exclude-standard -z -- 'src/*.odin' 'content/*.odin' | xargs -0 -I {} odinfmt -path:{} -w

build port="8080":
    just generate
    mkdir -p bin
    odin build src {{odin_flags}} {{libs}} -out:{{app}} -define:WLLS_PORT={{port}}

run port="8080":
    @if lsof -nP -iTCP:{{port}} -sTCP:LISTEN; then \
        printf 'Port %s is already in use. Stop that server before running just run.\n' '{{port}}' >&2; \
        exit 1; \
    fi
    just build {{port}}
    ./{{app}}

# Print /resume to content/pages/resume.pdf with Chrome's print engine, and
# record the SHA-256 of the resume.md it printed; `just check` fails when the
# two drift apart. Set CHROME to use another Chrome or Chromium binary.
resume-pdf port="8097":
    #!/usr/bin/env bash
    set -euo pipefail
    if lsof -nP -iTCP:{{port}} -sTCP:LISTEN >/dev/null; then
        printf 'Port %s is in use; pass another: just resume-pdf <port>\n' '{{port}}' >&2
        exit 1
    fi
    just build {{port}}
    ./{{app}} >/dev/null 2>&1 &
    server=$!
    trap 'kill $server' EXIT
    for _ in $(seq 50); do curl -sf localhost:{{port}}/healthz >/dev/null && break; sleep 0.1; done
    "${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}" \
        --headless=new --disable-gpu --no-pdf-header-footer --hide-scrollbars \
        --print-to-pdf=content/pages/resume.pdf "http://localhost:{{port}}/resume"
    shasum -a 256 content/pages/resume.md | cut -d ' ' -f 1 > content/pages/resume.pdf.sha256

check port="8080":
    just generate
    odin check src {{odin_flags}} -vet -vet-packages:main -define:WLLS_PORT={{port}}
    odin test src/app {{odin_flags}} {{libs}} -define:ODIN_TEST_THREADS=1
    odin test src/httpx {{odin_flags}} -define:ODIN_TEST_THREADS=1
    odin test src/views {{odin_flags}} {{libs}} -define:ODIN_TEST_THREADS=1
    odin test src/assets {{odin_flags}} -define:ODIN_TEST_THREADS=1
    odin test src/content {{odin_flags}} {{libs}} -define:ODIN_TEST_THREADS=1
