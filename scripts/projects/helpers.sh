make_all_projects() {
    local target="$1"
    shift  # reszta argumentów ($@) to to, co poleci dalej do "make"

    for dir in */; do
        [ -d "$dir" ] || continue
        if [ -f "$dir/Makefile" ]; then
            ( cd "$dir" && make "$target" "$@" )
        fi
    done
}
