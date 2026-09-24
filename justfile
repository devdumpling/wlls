app := "bin/wlls"

default:
    @just --list

generate:
    tempo generate src/views -runtime=tempo:runtime

build port="8080":
    just generate
    mkdir -p bin
    odin build src -collection:tempo={{env_var("TEMPO_SRC")}} -out:{{app}} -define:TINA_ASSERTS=true -define:WLLS_PORT={{port}} -thread-count:1

run port="8080":
    @if lsof -nP -iTCP:{{port}} -sTCP:LISTEN; then \
        printf 'Port %s is already in use. Stop that server before running just run.\n' '{{port}}' >&2; \
        exit 1; \
    fi
    just build {{port}}
    ./{{app}}

check port="8080":
    just generate
    odin check src -collection:tempo={{env_var("TEMPO_SRC")}} -vet -vet-packages:main -define:TINA_ASSERTS=true -define:WLLS_PORT={{port}} -thread-count:1
    odin test src/views -collection:tempo={{env_var("TEMPO_SRC")}} -thread-count:1
