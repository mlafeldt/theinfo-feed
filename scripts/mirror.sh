#!/usr/bin/env bash
# Mirror https://www.theinformation.com/feed into public/.
# Writes nothing if the upstream payload is byte-identical to what we already have,
# so the git history only records real upstream changes.
set -euo pipefail

UPSTREAM="${UPSTREAM:-https://www.theinformation.com/feed}"
OUT_DIR="${OUT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/public}"
FEED="$OUT_DIR/feed.xml"
META="$OUT_DIR/meta.json"

# Upstream serves plain clients an error page instead of the feed; this cookie is
# what makes it answer with XML.
if [ -z "${CF_CLEARANCE:-}" ]; then
	echo "refusing to mirror: CF_CLEARANCE is unset" >&2
	exit 1
fi

# The value is copied either bare or as a full name=value pair. Accept both.
CF_CLEARANCE="${CF_CLEARANCE#cf_clearance=}"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
body="$tmp_dir/feed.xml"
headers="$tmp_dir/headers.txt"

# --write-out reports the final response's headers, so redirects need no special
# handling. A header upstream did not send comes through as an empty line.
# No If-None-Match: a 304 has no body, and comparing bytes locally is simpler
# than teaching every caller to handle an empty payload.
curl --fail --silent --show-error --location \
	--retry 5 --retry-delay 5 --retry-all-errors \
	--max-time 60 \
	--cookie "cf_clearance=$CF_CLEARANCE" \
	--write-out '%header{last-modified}\n%header{etag}\n' \
	--output "$body" \
	"$UPSTREAM" >"$headers"

# A rejected request comes back as an error page, which curl --fail already
# catches. This guards the subtler case: a 200 carrying something that is not the
# feed. Requiring an entry means an empty-but-well-formed feed never overwrites a
# good mirror either.
if ! grep -q '<feed' "$body" || ! grep -q '<entry' "$body"; then
	echo "refusing to mirror: $UPSTREAM returned a payload that is not an Atom feed" >&2
	echo "first 200 bytes:" >&2
	head -c 200 "$body" >&2
	echo >&2
	exit 1
fi

# The feed-level <updated> precedes every entry's, so the first match is the one
# describing the feed as a whole.
feed_updated=$(grep -m1 -o '<updated>[^<]*</updated>' "$body" | sed 's/<[^>]*>//g')
entries=$(grep -c '<entry' "$body")

mkdir -p "$OUT_DIR"

# This guard also keeps CI honest: without it, meta.json's mirrored_at would
# change on every run and the workflow would commit every run.
if [ -f "$FEED" ] && cmp -s "$body" "$FEED"; then
	echo "unchanged: $entries entries, updated $feed_updated"
	exit 0
fi

{ read -r last_modified; read -r etag; } <"$headers"

# Headers upstream did not send become null, not "".
jq -n \
	--arg upstream "$UPSTREAM" \
	--arg mirrored_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
	--arg last_modified "$last_modified" \
	--arg etag "$etag" \
	--arg feed_updated "$feed_updated" \
	--argjson entries "$entries" \
	'{upstream: $upstream, mirrored_at: $mirrored_at, last_modified: $last_modified, etag: $etag, feed_updated: $feed_updated, entries: $entries}
	| (.last_modified, .etag) |= (if . == "" then null else . end)' \
	>"$tmp_dir/meta.json"

# Publish both files only after both exist, so a failure midway cannot leave a
# fresh feed.xml next to a stale or empty meta.json.
cp "$body" "$FEED"
cp "$tmp_dir/meta.json" "$META"

echo "updated: $entries entries, updated $feed_updated"
