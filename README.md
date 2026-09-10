# theinfo-feed

A mirror of [theinformation.com/feed](https://www.theinformation.com/feed), refreshed hourly
and served from GitHub Pages:

```
https://mlafeldt.github.io/theinfo-feed/feed.xml
```

## Why

Since early September 2026 the upstream feed sits behind a Cloudflare rule that answers feed
readers with an HTML challenge page where the XML should be, so they fail to parse it. The feed
itself is fine — it renders in a browser, and its content is public. This mirror republishes
those bytes unchanged so a reader can subscribe again.

I reported the block to The Information, both by support ticket and
[on X](https://x.com/mlafeldt/status/2097408295665381768). It looks like a misconfiguration
rather than a policy change, so treat this mirror as a stopgap — once they fix it, point your
reader back at the original.

## How

`scripts/mirror.sh` fetches the feed, refuses to write anything that is not an Atom feed with
at least one entry, and rewrites `public/` only when the payload actually changed. The workflow
commits and redeploys only on a real change.

A change in the bytes is not always an editorial one, though. Entries get re-stamped in bulk:
unrelated briefings, some a day apart in publication, converge on one `<updated>` value while
their title, summary and author stay byte-identical, and the feed-level `<updated>` moves with
them. The cause looks like a re-render rather than an edit, so expect commits that carry no new
writing.

It also fails the run outright if an entry id carries `info-reader-production.herokuapp.com`,
upstream's Heroku origin hostname, which it briefly rendered into entry links and ids on
2026-09-10 in place of its own. Those URLs point at a host where no subscriber can sign in, so a
red run and a stale mirror beat republishing them.

Fetching needs a `CF_CLEARANCE` repository secret. Run it locally with:

```console
$ CF_CLEARANCE=... ./scripts/mirror.sh
updated: 20 entries, updated 2026-09-09T08:03:46Z
```

A bad or expired value fails the run rather than mirroring an error page: the fetch itself
fails, and `mirror.sh` rejects any response that is not an Atom feed before it can overwrite
`public/feed.xml`.

## Scope

This mirrors the **public** feed only — the same headlines and summaries the URL above serves
any visitor, with no article bodies and nothing from behind the paywall. Unofficial, not
affiliated with or endorsed by The Information.
