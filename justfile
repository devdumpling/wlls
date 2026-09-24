app := "bin/wlls"

default:
    @just --list

build port="8080":
    mkdir -p bin
    odin build src -out:{{app}} -define:TINA_ASSERTS=true -define:WLLS_PORT={{port}}

run port="8080":
    @if lsof -nP -iTCP:{{port}} -sTCP:LISTEN; then \
        printf 'Port %s is already in use. Stop that server before running just run.\n' '{{port}}' >&2; \
        exit 1; \
    fi
    just build {{port}}
    ./{{app}}

check port="8080":
    odin check src -vet -vet-packages:main -define:TINA_ASSERTS=true -define:WLLS_PORT={{port}}
