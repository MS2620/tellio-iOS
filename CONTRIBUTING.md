# Contributing to Tellio for iPhone and iPad

Thanks for helping. Bug fixes, small improvements and new ideas are all welcome.

## Before you start

- **Bugs:** check the [issues](https://github.com/MS2620/tellio-iOS/issues) first. If it isn't there, open one, or go straight to a pull request for a small, obvious fix.
- **New features or design changes:** open an issue first to talk it through, so you don't spend time on something that won't be merged. Changes to how screens look are agreed on a design before they're built.
- **Shared code:** everything in `Vendor/tellio` (Core, Services, Shared) comes from [Tellio for Apple TV](https://github.com/MS2620/tellio). Send changes to it there, not here.

## Making a change

You don't need a Mac. Builds run on GitHub Actions, and you can also build on Linux or WSL with xtool (see the README).

1. Fork this repository and create a branch.
2. Make your change. Keep to the style around it: SwiftUI, British English in the app's text, short plain wording.
3. Push to your fork. The **Build** workflow compiles it and attaches an unsigned IPA to the run, which you can sideload to test on your own iPhone or iPad. Features that need build secrets (built-in TMDB and Trakt, crash reports, feedback) are off in your fork's builds; enter your own TMDB token and Trakt app in Settings › Connections to test those parts.
4. Open a pull request against `main`. Say what it changes, why, and how you tested it.

## Rules

- **Never commit keys, tokens, passwords, server addresses or addon links**, and don't put real ones in screenshots or issues.
- Don't name IPTV providers or addons in code, comments, issues or pull requests.
- Nothing may send logins, stream links, server or channel names, IP addresses or watch history anywhere, including crash reports.
- Text changes to `*.md` files and `LICENSE` don't trigger a build.

## Licence

Tellio isn't open source. You may fork and change it only to prepare contributions to this repository, and by sending a pull request you agree to the contribution terms in [LICENSE](LICENSE): you keep the copyright in your work and grant Mauro Sousa a licence to use and distribute it as part of Tellio.
