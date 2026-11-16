# MockDataStoreService (test only)

Vendored from https://github.com/buildthomas/MockDataStoreService at commit
`c428562d72fa76ac6ff48a2efbc45e40f22c5d8d` (2023-03-18), Apache-2.0 (see LICENSE). Only `lib/MockDataStoreService`
is copied, unmodified. It is used by `tests/luau/datastore.spec.luau` in Lune only. It is outside `src/`
and not in `default.project.json`, so it never reaches the place build. Safety read: plain Luau, no network
(HttpService only for JSON encode/decode), no loadstring/require-by-id.
