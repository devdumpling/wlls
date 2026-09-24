app := "bin/wlls"

default:
    @just --list

generate:
    tempo generate src/views -runtime=tempo:runtime

build port="8080":
    just generate
    mkdir -p bin
    odin build src -collection:tempo={{env_var("TEMPO_SRC")}} -extra-linker-flags:"-L{{env_var("CMARK_GFM_LIB")}}" -out:{{app}} -define:TINA_ASSERTS=true -define:WLLS_PORT={{port}} -thread-count:1

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
    odin test src/views -collection:tempo={{env_var("TEMPO_SRC")}} -extra-linker-flags:"-L{{env_var("CMARK_GFM_LIB")}}" -define:ODIN_TEST_THREADS=1 -thread-count:1
    odin test src/content -extra-linker-flags:"-L{{env_var("CMARK_GFM_LIB")}}" -define:ODIN_TEST_THREADS=1 -thread-count:1
