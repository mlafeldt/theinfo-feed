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
commits and redeploys only on a real change, so the history records upstream updates and
nothing else.

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
