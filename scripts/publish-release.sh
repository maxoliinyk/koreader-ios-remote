#!/bin/sh
# Upload complete, clearly labeled assets before making a release public.
set -eu

release_tag=${1:?Usage: publish-release.sh vX.Y or vX.Y.Z}
release_version=${release_tag#v}
release_repository=${GH_REPO:?Set GH_REPO to owner/repository}
if ! printf '%s\n' "$release_tag" | grep -Eq '^v[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
    echo "Use a vX.Y or vX.Y.Z release tag" >&2
    exit 2
fi
release_assets=${DIST_DIR:-dist}
release_template=$(dirname "$0")/../.github/RELEASE_TEMPLATE.md
release_changes=$(dirname "$0")/../release-notes/$release_version.md
release_notes="$release_assets/RELEASE_NOTES.md"
release_ipa="$release_assets/KORemoteAltStore-$release_version-unsigned.ipa"
release_plugin="$release_assets/remote_turner-$release_version.koplugin.zip"
for release_file in "$release_ipa" "$release_plugin" "$release_assets/SHA256SUMS"; do
    test -s "$release_file" || { echo "Missing release asset: $release_file" >&2; exit 2; }
done
if ! printf '%s\n' "$release_repository" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
    echo "GH_REPO must be owner/repository" >&2
    exit 2
fi
if ! test -f "$release_changes" || ! LC_ALL=C grep -q '[^[:space:]]' "$release_changes"; then
    echo "Add release notes to release-notes/$release_version.md before publishing" >&2
    exit 2
fi
{
    cat "$release_changes"
    printf '\n\n'
    sed -e "s/@TAG@/$release_tag/g" -e "s|@REPOSITORY@|$release_repository|g" \
        "$release_template"
} > "$release_notes"

# Resume an interrupted draft, but never replace an already published release.
if release_draft=$(gh release view "$release_tag" --json isDraft --jq .isDraft 2>/dev/null); then
    if test "$release_draft" != true; then
        echo "This release is already published; its assets will not be replaced" >&2
        exit 2
    fi
    gh release edit "$release_tag" --title "KORemote $release_tag" --notes-file "$release_notes"
else
    gh release create "$release_tag" --verify-tag --draft \
        --title "KORemote $release_tag" --notes-file "$release_notes"
fi

gh release upload "$release_tag" --clobber \
    "$release_ipa#iOS IPA — AltStore Classic" \
    "$release_plugin#KOReader Plugin" \
    "$release_assets/SHA256SUMS#SHA-256 Checksums"
gh release edit "$release_tag" --draft=false --latest
