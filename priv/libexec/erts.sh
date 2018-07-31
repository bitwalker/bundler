#!/usr/bin/env bash

set -o posix
set -e

code_paths() {
    __rel="$RELEASE_ROOT_DIR/releases/$REL_VSN/$REL_NAME.rel"
    grep -E '[{][A-Za-z_]*,\"[0-9.]*[A-Za-z0-9.\_\-\+]*\"(,[a-z]*)?[}]' "$__rel" \
        | grep -v "erts" \
        | sed -e's/"[^"]*$//' \
              -e's/^[^a-z]*//' \
              -e's/,/-/' \
              -e's/"//' \
              -e"s|^|$RELEASE_ROOT_DIR/lib/|" \
              -e's|$|/ebin|' \
        | tr '\n' ' '
}

# Echoes the path to the current ERTS binaries, e.g. erl
whereis_erts_bin() {
    if [ -z "$ERTS_VSN" ]; then
        set +e
        __erts_bin="$(dirname "$(type -P erl)")"
        set -e
        echo "$__erts_bin"
    else
        if [ -z "$USE_HOST_ERTS" ]; then
            __erts_dir="$RELEASE_ROOT_DIR/erts-$ERTS_VSN"
            if [ -d "$__erts_dir" ]; then
                echo "$__erts_dir/bin"
            else
                ERTS_VSN=
                whereis_erts_bin
            fi
        else
            ERTS_VSN=
            whereis_erts_bin
        fi
    fi
}

# Invokes erl with the provided arguments
erl() {
    __erl="$(whereis_erts_bin)/erl"
    if [ -z "$__erl" ]; then
        fail "Erlang runtime not found. If Erlang is installed, ensure it is in your PATH"
    else
        "$__erl" "$@"
    fi
}

# Run Elixir
elixir() {
    if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
      echo "Usage: `basename $0` [options] [.exs file] [data]

      -e COMMAND                  Evaluates the given command (*)
      -r FILE                     Requires the given files/patterns (*)
      -S SCRIPT                   Finds and executes the given script in PATH
      -pr FILE                    Requires the given files/patterns in parallel (*)
      -pa PATH                    Prepends the given path to Erlang code path (*)
      -pz PATH                    Appends the given path to Erlang code path (*)

      --app APP                   Starts the given app and its dependencies (*)
      --cookie COOKIE             Sets a cookie for this distributed node
      --detached                  Starts the Erlang VM detached from console
      --erl SWITCHES              Switches to be passed down to Erlang (*)
      --help, -h                  Prints this message and exits
      --hidden                    Makes a hidden node
      --logger-otp-reports BOOL   Enables or disables OTP reporting
      --logger-sasl-reports BOOL  Enables or disables SASL reporting
      --name NAME                 Makes and assigns a name to the distributed node
      --no-halt                   Does not halt the Erlang VM after execution
      --sname NAME                Makes and assigns a short name to the distributed node
      --version, -v               Prints Elixir version and exits
      --werl                      Uses Erlang's Windows shell GUI (Windows only)

    ** Options marked with (*) can be given more than once
    ** Options given after the .exs file or -- are passed down to the executed code
    ** Options can be passed to the Erlang runtime using ELIXIR_ERL_OPTIONS or --erl" >&2
      exit 1
    fi
    MODE="elixir"
    ERL=""
    I=1
    while [ $I -le $# ]; do
        S=1
        eval "PEEK=\${$I}"
        case "$PEEK" in
            +iex)
                MODE="iex"
                ;;
            +elixirc)
                MODE="elixirc"
                ;;
            -v|--compile|--no-halt)
                ;;
            -e|-r|-pr|-pa|-pz|--remsh|--app)
                S=2
                ;;
            --detatched|--hidden)
                ERL="$ERL `echo $PEEK | cut -c 2-`"
                ;;
            --cookie)
                I=$(expr $I + 1)
                eval "VAL=\${$I}"
                ERL="$ERL -setcookie "$VAL""
                ;;
            --sname|--name)
                I=$(expr $I + 1)
                eval "VAL=\${$I}"
                ERL="$ERL `echo $PEEK | cut -c 2-` "$VAL""
                ;;
            --logger-otp-reports)
                I=$(expr $I + 1)
                eval "VAL=\${$I}"
                if [ "$VAL" = 'true' ] || [ "$VAL" = 'false' ]; then
                    ERL="$ERL -logger handle_otp_reports "$VAL""
                fi
                ;;
            --logger-sasl-reports)
                I=$(expr $I + 1)
                eval "VAL=\${$I}"
                if [ "$VAL" = 'true' ] || [ "$VAL" = 'false' ]; then
                    ERL="$ERL -logger handle_sasl_reports "$VAL""
                fi
                ;;
            --erl)
                I=$(expr $I + 1)
                eval "VAL=\${$I}"
                ERL="$ERL "$VAL""
                ;;
            *)
                break
                ;;
        esac
        I=$(expr $I + $S)
    done
    if [ "$MODE" != "iex" ]; then ERL="-noshell -s elixir start_cli $ERL"; fi
    __code_path="$(code_paths)"
    erl -boot_var ERTS_LIB_DIR "$ERTS_DIR/../lib" \
        -boot "$RELEASE_ROOT_DIR/bin/start_clean" \
        -pa $__code_path \
        -pa "$CONSOLIDATED_DIR" \
        $ELIXIR_ERL_OPTIONS $ERL -extra "$@"
}

# Run IEx
iex() {
    elixir --no-halt --erl "-noshell -user Elixir.IEx.CLI" +iex "$@"
}

# Echoes the current ERTS version
erts_vsn() {
    erl -eval 'Ver = erlang:system_info(version), io:format("~s~n", [Ver])' -noshell -boot start_clean -s erlang halt
}

# Echoes the current ERTS root directory
erts_root() {
    erl -eval 'io:format("~s~n", [code:root_dir()]).' -noshell -boot start_clean -s erlang halt
}

# Echoes the current OTP version
otp_vsn() {
    erl -eval 'Ver = erlang:system_info(otp_release), io:format("~s~n", [Ver])' -noshell -boot start_clean -s erlang halt
}

# Use release_ctl for local operations
# Use like `release_ctl eval "IO.puts(\"Hi!\")"`
release_ctl() {
    command="$1"; shift
    elixir -e "Mix.Releases.Runtime.Control.main" \
           -- \
           "$command" "$@"
}

# Use release_ctl for remote operations
# Use like `release_remote_ctl ping`
release_remote_ctl() {
    command="$1"; shift
    name="${PEERNAME:-$NAME}"
    elixir -e "Mix.Releases.Runtime.Control.main" \
           -- \
           "$command" \
           --name="$name" \
           --cookie="$COOKIE" \
           "$@"
}

# DEPRECATED: Use release_remote_ctl instead
nodetool() {
    release_remote_ctl "$@"
}

# Run an escript in the node's environment
# Use like `escript "path/to/escript"`
escript() {
    scriptpath="$1"; shift
    export RELEASE_ROOT_DIR
    __escript="$(whereis_erts_bin)/escript"
    "$__escript" "$ROOTDIR/$scriptpath" "$@"
}

# Test erl to make sure it works
if erl -eval 'io:format("ok~n", [])' -noshell -boot start_clean -s erlang halt 2>/dev/null | grep "ok" >/dev/null; then
    export ROOTDIR
    ROOTDIR="$(erts_root)"
    export ERTS_VSN
    if [ -z "$ERTS_VSN" ]; then
        # Update start_erl.data
        ERTS_VSN="$(erts_vsn)"
        echo "$ERTS_VSN $REL_VSN" > "$START_ERL_DATA"
    fi
    ERTS_VSN="$(erts_vsn)"
    export ERTS_DIR
    ERTS_DIR="$ROOTDIR/erts-$ERTS_VSN"
    export BINDIR
    BINDIR="$ERTS_DIR/bin"
    export ERTS_LIB_DIR
    ERTS_LIB_DIR="$ERTS_DIR/../lib"
    export EMU="beam"
    export PROGNAME="erl"
else
    fail "Unusable Erlang runtime system! This is likely due to being compiled for another system than the host is running"
fi
