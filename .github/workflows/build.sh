#!/usr/bin/env bash
set -Eeuo pipefail

# Usage: build.sh <book-lang> <dest-dir>
#
# Build the course as of the date specified specified in the
# POT-Creation-Date header of po/$book_lang.po. The output can be
# found in $dest_dir.
#

book_lang=${1:?"Usage: $0 <book-lang> <dest-dir>"}
dest_dir=${2:?"Usage: $0 <book-lang> <dest-dir>"}

if [ "$book_lang" = "en" ]; then
    echo "::group::Building English course"
else
    pot_creation_date=$(grep --max-count 1 '^"POT-Creation-Date:' "po/$book_lang.po" | sed -E 's/".*: (.*)\\n"/\1/')
    pot_creation_date=${pot_creation_date:-now}
    echo "::group::Building $book_lang translation as of $pot_creation_date"

    export MDBOOK_BOOK__LANGUAGE=$book_lang
fi

mdbook build -d "$dest_dir"

echo "::endgroup::"
