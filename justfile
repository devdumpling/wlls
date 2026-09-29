app := "bin/wlls"

# Build settings shared by every Odin invocation. flake.nix mirrors the egress
# size for release builds (without the development flags); src/app/conf.odin
# asserts it, so a build that forgets it fails to compile.
odin_defines := "-define:HTTP_EGRESS_BUFFER_SIZE=16384 -define:TINA_ASSERTS=true -define:WLLS_DEV=true"
odin_flags := "-collection:tempo=" + env_var("TEMPO_SRC") + " -thread-count:1 " + odin_defines
cmark := '-extra-linker-flags:"-L' + env_var("CMARK_GFM_LIB") + '"'

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
    odin build src {{odin_flags}} {{cmark}} -out:{{app}} -define:WLLS_PORT={{port}}

run port="8080":
    @if lsof -nP -iTCP:{{port}} -sTCP:LISTEN; then \
        printf 'Port %s is already in use. Stop that server before running just run.\n' '{{port}}' >&2; \
        exit 1; \
    fi
    just build {{port}}
    ./{{app}}

check port="8080":
    just generate
    odin check src {{odin_flags}} -vet -vet-packages:main -define:WLLS_PORT={{port}}
    odin test src/app {{odin_flags}} {{cmark}} -define:ODIN_TEST_THREADS=1
    odin test src/httpx {{odin_flags}} -define:ODIN_TEST_THREADS=1
    odin test src/views {{odin_flags}} {{cmark}} -define:ODIN_TEST_THREADS=1
    odin test src/assets {{odin_flags}} -define:ODIN_TEST_THREADS=1
    odin test src/content {{odin_flags}} {{cmark}} -define:ODIN_TEST_THREADS=1
