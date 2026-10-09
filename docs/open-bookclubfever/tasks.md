# BookClubFever Demo - Build Tracker

**Spec:** [`bookclubfever-demo-spec.md`](bookclubfever-demo-spec.md)
**Process:** `OPEN-SOURCE-PLAYBOOK.md` steps 4-12
**Boilerplate:** open-base (scaffolded with `new-open-app.sh bookclubfever "BookClubFever" "..."`)

| # | Phase | Status |
|---|---|---|
| 1 | Branding and config: `.env(.example)`, layout fallback name, accent CSS (fever red + marigold), landing page; base dashboard removed | `[x]` |
| 2 | Models: `BookPick`, `ConversationSet` migrations, validations, constants, associations | `[x]` |
| 3 | Routes and controllers: `BookPicksController` CRUD, `ConversationSetsController` (index redirect, rate limit, rescues) | `[x]` |
| 4 | Views and Stimulus: dashboard, form, book page, result page (disclaimer, Download .md, raw toggle, unsure and stale banners), `generating`, `form_submit`, `download_markdown` | `[x]` |
| 5 | AI integration: `bookclubfever_openers_v1` prompt, parser, `ChapterBoundaryCheck`, `ProgressShameCheck` | `[x]` |
| 6 | Seeds: template, fictional Alder Street library club's *Frankenstein* with a completed set; `demo_placeholder_v1` removed from seeds and the DB | `[x]` |
| 7 | Guardrails and evals: `config/ai_guards.yml`, `evals/cases/bookclubfever_openers_v1.yml` (8 cases, code rules mirrored), placeholder case removed | `[x]` |
| 8 | Specs: models, both check services, requests; `bundle exec rspec` green; `bin/rails evals:guardrails` PASS | `[x]` |
| 9 | README rewrite, UI journey manifest (port 3125), pre-publish check, local commit | `[x]` |

## Quick reference

```
book_picks_path                          GET  /books   (also /dashboard)
new_book_pick_path                       GET  /books/new
book_pick_path(b)                        GET  /books/:id
edit_book_pick_path(b)                   GET  /books/:id/edit
book_pick_conversation_sets_path(b)      POST /books/:id/openers   (GET redirects to the book)
book_pick_conversation_set_path(b, s)    GET  /books/:id/openers/:id
```

```
Template:   bookclubfever_openers_v1   (gemini-2.5-flash, 8192 max tokens, temperature 0.6)
Variables:  title, author, read_through (boundary sentence), club_vibe (phrase), reader_notes
JSON:       book_familiarity (known|unsure), spoiler_boundary,
            openers[5]{question <=160, angle, why_it_works, follow_up}, spoiler_free_line,
            next_reads[3]{title, author, tie_in}
Code rules: ChapterBoundaryCheck, ProgressShameCheck, no links, >=3 angles, next read != this book
```

## Not done here (needs the owner)

- Live runs: `bin/rails evals:run` and `./ui-journey-fleet.sh --yes open-bookclubfever` (real Gemini calls), and `./ui-journey-fleet.sh --free open-bookclubfever` (needs the server, not started by the build agent).
- `Open/README.md` app count and `git open repos.md` remote line (shared files, updated by the coordinator).
- GitHub repo creation and push.
