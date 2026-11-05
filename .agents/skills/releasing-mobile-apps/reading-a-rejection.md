# Reading and answering a rejection

A rejection is a message with a policy or guideline, a finding, sometimes a
screenshot, and what to change. Clarifying and appealing are normal
outcomes, not failures. Many are fixed without a new build.

## 1. Get the text, verbatim

- **App Store**: App Store Connect, the app, App Review, the submission;
  and the email to the account holder.
- **Google Play**: Play Console, Inbox and Policy status; and the email to
  the developer account.

Ask the user to paste it whole: the guideline or policy name, the
reviewer's sentences, the device and OS, the date. Do not work from a
paraphrase. Record it in the repo (for example `docs/STORE_HISTORY.md`)
with the date, so the next submission knows the history.

## 2. Classify it

**A question** (Apple's "Information Needed", 2.1; Google asking for app
access or a permission justification): answer in the review conversation or
the declaration form, precisely and briefly, with steps. No new build
unless the answer is "you are right, it is broken".

**Metadata** (Apple 2.3, listing text, screenshots, privacy labels, age
rating; Google's Metadata policy, Data safety, content rating): fixed in the
console by the user. No build. Apple: reload to confirm the save, then
"Update Review" and resubmit the same submission. Google: fix, then send
the changes for review from Publishing overview.

**Binary** (a crash, a missing feature, billing, permissions, account
deletion, a policy in the code): a code change, a raised build number, a
new upload through App Builder.

Some are two at once. The subtitle that says "iPhone" is a metadata fix;
the missing account deletion behind it is a build.

## 3. Read the requested change literally

The reviewer writes exactly what they want to see. "Please provide a demo
account" means a working account in the review notes or App access. "Please
revise the subtitle" means the subtitle. Do that thing; do not also change
three other things and hope.

## 4. App Store: common ones

| Reviewer says | It usually means | Fix |
|---|---|---|
| 2.1 could not sign in | the demo account expired, is rate-limited, or the backend was down for the US | a fresh account, tested now, in Notes for Review |
| 2.1 could not locate the feature | behind a flag, a region, or steps the notes did not mention | steps in Notes for Review, or unhide it |
| 2.3.x metadata or screenshots | screenshots of a different state, or a claimed feature that is not there | real screenshots of this build, by the user |
| 3.1.1 IAP | an unlock goes around StoreKit, or Restore is missing | StoreKit for every digital unlock; Restore Purchases |
| 3.1.2 subscription disclosure | the paywall lacks price, period, renewal or cancellation | put them on the paywall, plus Terms and Privacy links |
| 4.8 login services | a social login without Sign in with Apple | add it beside the others |
| 5.1.1 (v) account deletion | no in-app way to delete the account | build it, name the path in Notes for Review |
| 5.1.1 permission | a vague purpose string, or a prompt before the user does anything related | name the feature and benefit; ask at the moment of use |
| 5.1.2 data use | a third party gets data with no in-app disclosure and consent | disclosure and consent before the first send |
| 4.2 minimum functionality | a web view, a single screen, "not useful enough" | native features, real content; sometimes an appeal |
| 2.5.1 private APIs | an SDK calls something Apple does not allow | update or remove the SDK; the reviewer names the symbol |
| 4.3 spam | the same template as many store apps | an appeal saying what is different, or a real change |

## 5. Google Play: common ones

| Play says | It usually means | Fix |
|---|---|---|
| App access: could not log in | no credentials in App access, or they stopped working | working credentials and steps in App access |
| Data safety: data collection not disclosed | an SDK sends data the form does not list | audit every SDK, update the form |
| User data: prominent disclosure | personal data collected without an in-app notice first | a disclosure screen before collecting |
| Account deletion requirements | no in-app deletion, or no web deletion link | build it; add the link in Data safety |
| Permissions: not core functionality | a sensitive permission without a declaration or a core reason | remove it from the merged manifest, or file the declaration |
| Metadata: misleading or keyword stuffing | ranking words, other brands, repeated keywords in the listing | rewrite the listing |
| Broken functionality | a crash or a blank screen on Google's devices | the pre-launch report shows where; fix and upload |
| Target API level | `targetSdk` below the current requirement | raise `targetSdk`, test, upload |
| Payments | a digital unlock outside Play Billing | Play Billing, unless enrolled in an alternative program |

## 6. Replying

Replies come from the user's console: Apple's App Review conversation,
Google's appeal form or the declaration itself. Draft it for them: short,
factual, one paragraph per point, exact steps, what changed and where.
Thank nobody; argue nowhere. If the finding is wrong, say so plainly with
evidence (a screen recording from a real phone proves a feature works) and
ask them to look again.

An appeal (Apple's App Review Board, Google's policy appeal) is for a
finding that is wrong on the rule, not one you disagree with on taste. Both
take days. Apple's expedited review is for a live app with a serious bug;
ask once, with the impact.

## 7. Resubmitting

- Metadata only: fix in the console, resubmit the same build.
- New build: raise the build number, `POST $APP/testflight` or
  `POST $APP/play`, then the user attaches it to the version or release
  and resubmits. An Apple version still Waiting for Review is removed from
  review by the user first.
- Record the new status with the date: "checked 2026-10-21: In Review,
  build 43".

## 8. Test tracks are not the final review

Apple's Beta App Review (external TestFlight groups) and Google's review of
closed and open tracks are lighter than the full review: crashes, broken
builds, obvious violations. Passing them says little about App Review or a
production release. Internal TestFlight groups and Play's internal track
skip review, which is why a first build goes there and onto a real phone
before anything else.

The App Store part is adapted from templetongroup/app-store-review (MIT).
