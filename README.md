# DaliDeck for Android

DaliDeck ported to a native Flutter Android app. Two-way sync with the website
([DALI951/DaliDeck](https://github.com/DALI951/DaliDeck)) through a self-hosted API.

## Data formats

The JSON state mirrors the web app exactly (`dalideck.v1`, `v:2`), so the app and
the website can seed and merge each other's data via a shared sync key.

- Money amounts and balances are in **millimes** (1000 = 1 TND).
- Timetable cells map `"<periodId>:<weekday>"` (weekday 0=Mon..6=Sun) to a subject id.
- Dates are `YYYY-MM-DD` strings.

## Build

The APK is built by GitHub Actions (never locally). Push a tag `v*` to publish a
Release with the signed APK.

```bash
git tag v0.2.0 && git push origin v0.2.0
```

Signing keystore is injected from secrets: `KEYSTORE_B64`, `KEYSTORE_PASS`,
`KEYSTORE_ALIAS`, `KEYSTORE_KEY_PASS`.