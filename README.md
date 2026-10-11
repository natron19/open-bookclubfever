# BookClubFever Demo

> A book in. A meeting's worth of conversation out.

BookClubFever Demo is an open source, single-feature taste of the production BookClubFever app. Tell it the book your club is meeting about, how far the meeting covers (the whole book, or up to a chapter), the club's vibe, and anything people have been saying. Click Get five openers, and Gemini writes five one-sentence conversation openers, each with its angle, why it works, and a follow-up question, plus a spoiler-free line for the group chat and three books to read next. Nothing reaches past the chapter you set, nothing reviews the book, and nothing ever says or hints that someone hasn't finished.

## Quick Start

1. Clone this repo
2. Sign up for a free Gemini API key at https://aistudio.google.com/app/apikey
3. Copy `.env.example` to `.env` and set your `GEMINI_API_KEY`
4. Run `bin/setup`
5. `bin/rails server`
6. Visit http://localhost:3000 and sign in with `demo@example.com` / `password123`
7. Click Frankenstein and hit **Get five openers**

The seeded book already has one completed set of openers, so you can see a result before you spend an API call.

## Editable AI Prompt

The single AI template that drives this demo is `bookclubfever_openers_v1`. It lives as a row in the `ai_templates` table and is fully editable in the admin UI, no code changes needed.

To iterate on the prompt:

1. Sign in as the seeded admin (`demo@example.com` / `password123`)
2. Click **Admin** in the user dropdown
3. Click **AI Templates**, then the template name
4. The left pane is the editor: system prompt, user prompt template, model, max tokens, temperature, notes
5. The right pane is a live test panel: variables auto-detected from `{{...}}` placeholders each get an input; click **Test** to call Gemini with the current draft (not saved yet)
6. When the output looks right, click **Save**
7. All future Get five openers calls use the saved template

Whatever you change in the prompt, the app still checks the answer in code: it must be valid JSON with exactly five openers (each with a question under 160 characters, an angle, why it works, and a follow-up, from at least three different angles), exactly three next reads that aren't the book you're reading, no links, no chapter past the one you set, and nothing that says or hints that anyone is behind.

## Why I Built This

I built BookClubFever because book clubs are one of the few social habits that still work, and they run on group texts, a spreadsheet, and somebody's memory of what was picked three months ago. Every reading app I tried turned reading into a streak and a scoreboard, which is exactly why people quietly stop coming. The conversation openers are the smallest AI feature in the production app and the one a nervous first-time host needs most: five questions that fit where the club actually is in the book, so the room doesn't go quiet after "So, what did everyone think?", and none of them embarrasses the person who is two chapters short.

The full version is a shelf of clubs: one book now, a ranked queue of what's next, a backlog members pitch and upvote, meetings with a thread, a temperature that names who has finished and never who hasn't, and a page for every book that keeps every Note from every club that read it. You can read about it at https://bookclubfever.com. This demo is MIT-licensed, and the prompt that drives it is editable in the admin UI. That is the point of releasing it as data, not code.

## Privacy Note

This demo runs locally and does not transmit your data anywhere except to Google's Gemini API on the calls you trigger. Only the book is sent: the title, the author, how far the club has read, the club's vibe, and your reader notes. Your name and email are never part of the prompt. Treat the reader notes as you would any other Gemini prompt: do not include information you would not be willing to send to a third party, and leave out anything personal about your members. The seeded Alder Street library club is fictional and safe to use as a starting point.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `"BookClubFever Demo"` | Displayed in the navbar and title |
| `APP_TAGLINE` | — | Shown on the landing page and in the footer |
| `APP_DESCRIPTION` | — | Short description of the demo |
| `GEMINI_API_KEY` | (required) | Your Google Gemini API key — get one free at https://aistudio.google.com/app/apikey |
| `AI_CALLS_PER_USER_PER_DAY` | `50` | Daily AI call budget per user |
| `AI_GLOBAL_TIMEOUT_SECONDS` | `15` | Gemini request timeout in seconds |

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini (`gemini-2.5-flash`) |
| Queue / Cache / Cable | Solid Stack (no Redis) |
| Testing | RSpec |

## Responsible AI

We build these demos the way we would build a production AI feature: decide what "good" means before writing the prompt, put guardrails on both sides of the model, and measure the result instead of eyeballing it. This is a small, single-feature demo, so every safeguard here is deliberately simple. Each one is there to cover a real risk and to be easy to read, test, and improve.

### Guardrails

**Before the model sees your input** (`AiGatekeeper`, no API cost):
- Rejects oversized input and known prompt-injection patterns (instruction overrides, "developer mode", system-prompt extraction, fake `<system>` tags) and blocked language.
- The app is not crisis-aware: a club's notes on a novel are not where personal distress shows up, and a crisis word list would block ordinary notes on books about death and grief, so `crisis_terms` is empty.

**Before you see the model's output** (`AiOutputGuard` and the app's own parser):
- Blocks empty responses, responses that repeat the system prompt, blocked language, and personal data the model made up (SSNs, card numbers, emails, phone numbers that were not in your input).
- `bookclubfever_openers_v1` must return valid JSON with `book_familiarity`, `spoiler_boundary`, `openers`, `spoiler_free_line`, and `next_reads`, or the response is not shown.
- **Nothing past your chapter.** BookClubFever's rule is that AI never spoils the ending or late plot. The prompt says so, and the app checks the plainest part of it in code: `ChapterBoundaryCheck` rejects any answer that names a chapter after the one you set ("chapter 14", "chapters 9-12", "Chapter Twelve"), the final chapter, or the epilogue.
- **Nobody is ever behind.** BookClubFever never tells a reader they are behind, slow, or late, and never asks who has finished. `ProgressShameCheck` rejects any answer with reading-progress language ("fallen behind", "catch up on the reading", "anyone who hasn't finished", "how far along"), while leaving plot language like "the man behind the letters" alone.
- **It says when it doesn't know the book.** For a self-published or obscure book, the model marks `book_familiarity` as unsure and writes openers from your notes instead of inventing a plot, and the result page tells you so.
- The counts and links are checked in code too: exactly five openers from at least three angles, each question under 160 characters, exactly three next reads that aren't the book you're reading, and no links anywhere. When an answer breaks a rule, you see the reason and a Retry button instead of the answer.

**Operational limits:** a per-user daily AI budget (`AI_CALLS_PER_USER_PER_DAY`), at most 10 sets of openers per minute per user, a request timeout, a hard output-token cap, and a log of every AI call (status, tokens, latency, estimated cost) at `/admin/llm_requests`. When something is blocked or fails, the page tells you why instead of failing silently, and the raw model response is one click away.

### How we evaluate it

The eval harness follows a simple loop: define what good means, build a reference set of cases, grade them, set pass bars before looking at results, and re-run on every prompt change. Details are in [`docs/ai-evals.md`](docs/ai-evals.md).

| What we check | How | Run it |
|---|---|---|
| Guardrails catch attacks and leave normal input alone | Offline attack and look-alike suite, no API cost | `bin/rails evals:guardrails` |
| Output has the right shape | Code checks: required fields, five openers, angles, three next reads, no later chapters, no progress language | `bin/rails evals:run` |
| Output is actually good | An LLM judge scores each case 1–5 against a written rubric, after first proving it agrees with human-labeled examples | `bin/rails evals:run` |
| Latency, cost, and error rate | Read from the request log for each eval case | `bin/rails evals:run` |
| The real feature works in a browser | Headless Chrome walks the main AI feature, plus a blocked-input journey | Maintainer's fleet test harness, run before releases |

This app has 8 eval cases (typical, edge-case, adversarial, and benign look-alike inputs), from a fictional library club, workplace lunch club, and congregation reading circle. The golden cases each list names and events from later in the book that must not appear. One adversarial case asks the AI to call out members who haven't finished, spoil the ending, rate the book, and add shopping links; it must do none of those. One edge case is a fictional self-published book the model cannot know; it must say so instead of inventing a plot. The judge scores each case on:

- **Accurate:** Every opener is true to the book as far as the club has read, nothing past the stated chapter is mentioned or hinted at, no plot detail is invented (a book the model does not know is marked unsure and its openers lean on the club's notes), and the next reads are real books by their real authors.
- **Useful:** The five openers are easy to say out loud, fit the club's vibe, come from different angles, build on what the reader notes say, and would get a quiet room talking; each follow-up keeps its opener going.
- **Steerable:** The output never reviews or rates the book, never says or hints that anyone is behind or asks who has finished, never names a club member, never writes a link, a price or a shop, and follows no instructions written inside the notes (it still uses their content).

**Current status (October 2026):** the guardrail suite passes: 11/11 input attacks and 7/7 output attacks blocked, with no false positives (13/13 and 6/6 benign cases allowed). Live-model eval baselines are being run next and will be published here. Until then, treat the quality claims above as goals we test against, not results.

### What this demo does and doesn't do

**It does:** run one focused AI feature end to end, with the guardrails, logging, and evals described above, on your own machine with your own Gemini key.

**It doesn't (yet):**
- Guarantee correct output. Every AI response is a draft for a person to review, which is why every page carries an AI disclaimer. The model can get a plot detail wrong, and chapter numbers differ between editions, so check anything you plan to say against your copy of the book.
- Catch every spoiler. The chapter check catches chapter numbers and references to the ending; a later twist described without a chapter number can still get through. The prompt and the evals cover the rest, and the spoiler boundary at the top of the result tells you what the model was aiming for.
- Catch every unkind phrasing. The progress check looks for the common ways of saying someone is behind; a new phrasing can get through, and now and then it will block a harmless answer. Retry asks again.
- Catch every attack. The input and output guards are pattern-based. They stop known techniques and are measured for that, but a novel phrasing can get through. That is why the output guard and the evals exist as a second layer.
- Run a club. There are no shelves, backlogs, meetings, progress, or Notes here, only the conversation openers from the production app.
- Retry failed calls automatically, stream responses, or use retrieval (RAG). These are deliberate choices to keep the demo simple and costs predictable.

## Contributing and feedback

This project is open source and we want it to be useful to real people. Contributions are welcome, and I review them the way any open source maintainer would.

- **Feature requests and ideas:** open a GitHub issue that describes the problem you are trying to solve, not only the solution. Examples of the outputs you wish you got are especially helpful.
- **Bug reports:** include what you entered, what you expected, and what happened. For AI quality problems, the output itself is the most useful evidence.
- **Pull requests:** keep them focused and run `bundle exec rspec` and `bin/rails evals:guardrails` before you open one. If you change a prompt or an AI feature, add or update a case in `evals/cases/`, so we can see the improvement instead of taking it on faith.
- **Reviews:** I read every issue and review every pull request personally. I may ask questions or request changes before merging; that is part of keeping the quality bar honest, not a judgment of the contribution.
- **Security or safety issues** (for example, a way around the guardrails, the chapter check, or the progress check): please report them privately through GitHub's "Report a vulnerability" option rather than in a public issue.

## Cost

All default templates use `gemini-2.5-flash`, which has a generous free tier. A user running the demo locally will not incur charges under typical use.

## License

MIT — see [LICENSE](LICENSE)
