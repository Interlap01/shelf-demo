# App Store checklist

Walk this with the user before the first submission to App Review. Every
unchecked line is a review round trip of a day or more. Guideline numbers
are Apple's App Store Review Guidelines
(https://developer.apple.com/app-store/review/guidelines/). Most of this
can be checked from the project: the source, the Info.plist, the
entitlements, the paywall copy. What cannot (the listing in App Store
Connect, a fresh install on a phone) is marked *user*.

## Build quality (2.1, 2.4, 2.5)

- [ ] No crashes on a clean install with a fresh account, on a real device, on the current iOS (*user*, or a development build on a claimed phone)
- [ ] Smallest and largest supported screens tested; iPhone app runs on iPad if at all possible (2.4.1)
- [ ] Works on an IPv6-only network (2.5.5)
- [ ] Works with every permission denied (5.1.1)
- [ ] Works offline or on a bad connection: no spinner forever, no crash
- [ ] Public APIs only, no deprecated frameworks, no downloaded executable code (2.5.1, 2.5.2)
- [ ] Background modes limited to what they are declared for (2.5.4)
- [ ] No placeholder text, lorem ipsum, "coming soon" screens, dead links or debug menus anywhere
- [ ] `ITSAppUsesNonExemptEncryption` in Info.plist (false for HTTPS-only apps), or the user answers export compliance in App Store Connect for every build

## Reviewer access (2.1)

- [ ] Demo account created and tested **today**, not rate-limited, not expiring during review
- [ ] Backend, feature flags and remote config live for the reviewer's region (they review from the US)
- [ ] Every in-app purchase reachable and purchasable in the sandbox environment
- [ ] Hardware requirements stated, or a demo mode provided (a companion device the reviewer does not have)
- [ ] Notes for Review filled: demo credentials, what the app does, how it makes money, steps for anything non-obvious, regulatory documents. Limit 4,000 characters.

## Money (3.1)

- [ ] Digital content and features unlock through StoreKit only: no codes, no web checkout links, no crypto
- [ ] Physical goods and real-world services do **not** use in-app purchase
- [ ] Restore Purchases implemented and tested
- [ ] Paywall shows: price, billing period, "renews until cancelled", trial terms, how to cancel, links to Terms and Privacy Policy
- [ ] Subscriptions last at least 7 days and work across the user's devices
- [ ] No external purchase links outside the storefronts and entitlements that allow them
- [ ] Loot box or gacha odds disclosed before purchase, if any
- [ ] Nothing gated on rating the app, reviewing it or installing another app (3.2.2)

## Accounts (4.8, 5.1.1)

- [ ] Usable without login when accounts are not core to the app
- [ ] **In-app account deletion** shipped and reachable; the path written in Notes for Review
- [ ] Sign in with Apple (or an equivalent that limits data) offered beside any third-party social login
- [ ] Social tokens never stored off-device; credentials revocable in the app

## Privacy (5.1)

- [ ] Privacy policy URL in App Store Connect **and** linked inside the app
- [ ] The policy covers: what is collected, how, every use, third parties that receive it, retention and deletion, consent withdrawal
- [ ] Every `NS*UsageDescription` string names the feature and the benefit to the user ("to put your photo on your profile", not "needs camera access")
- [ ] Only the permissions the core features need
- [ ] App Tracking Transparency prompt if anything tracks across apps or sites; the app fully usable when declined
- [ ] App Privacy answers ("nutrition labels") audited against the code **and every third-party SDK**, then **published**, not only saved
- [ ] `PrivacyInfo.xcprivacy` present for the app and for SDKs Apple requires it from, with required-reason API entries
- [ ] Recording or logging user activity: consent plus a visible or audible indicator (2.5.14)
- [ ] Health data: never in iCloud, never for ads, disclosed specifically (5.1.3)
- [ ] Kids: no third-party ads or analytics, a parental gate, the Kids Category rules (1.3, 5.1.4)
- [ ] Third-party data sharing disclosed in the app and consented to before the first transmission; the policy alone is not enough

## User-generated content (1.2)

- [ ] A filter for objectionable content
- [ ] A report mechanism with a real process behind it
- [ ] Blocking abusive users
- [ ] Published contact information

## Metadata (2.3)

- [ ] App name 30 characters or fewer, globally unique across the store
- [ ] Name and subtitle contain no Apple trademarks (iPhone, iPad, Apple, Mac) and no competitor names
- [ ] Subtitle and description accurate, no unverifiable claims, no pricing
- [ ] Keywords: 100 characters, comma-separated, no spaces after commas, no trademarks, no competitor names
- [ ] Screenshots show the app **in use**, current UI, on the required device sizes; no device frames of other platforms
- [ ] Preview videos are real screen captures of the app
- [ ] Icon, screenshots and previews all suitable for 4+
- [ ] Category right; age rating answered honestly (match comparable shipped apps rather than chasing 4+)
- [ ] Description says which features or content need additional purchases
- [ ] "What's New" describes the actual changes
- [ ] Support URL live, with a working way to contact the developer (1.5)
- [ ] Generative AI features carry the disclosures they need; China's deep-synthesis rules apply there

## Legal (5.2 to 5.6)

- [ ] All content owned or licensed; third-party services' terms allow this use
- [ ] No embedded Apple emoji, no implied Apple endorsement, no look-alike Apple UI
- [ ] Regulated fields (finance, health, gambling) submitted by the licensed legal entity, geo-restricted where required
- [ ] Official review prompt API (`AppStore.requestReview` or `SKStoreReviewController`), not a custom rating dialog (5.6.1)

## Ads (2.5.18)

- [ ] Ads only in the main binary
- [ ] Age-appropriate for the app's rating; targeting information visible without leaving the app
- [ ] No targeting from health, classroom or kids' data
- [ ] Interstitials labelled, not deceptive, with a large, easy close button
- [ ] Users can report inappropriate ads

## The last five minutes

- [ ] `GET $APP/testflight` shows `last.error` empty for this build number
- [ ] The build shows in App Store Connect, processed, not expired (*user*)
- [ ] Export compliance answered for the build (*user*, unless Info.plist answers it)
- [ ] The version's metadata complete in App Store Connect (*user*): description, screenshots, age rating, pricing and availability, App Privacy published
- [ ] Release type decided: the user presses Release after approval, or it goes out on approval
- [ ] The user files the review themselves, in App Store Connect

Adapted from Apple's guidelines and from two MIT-licensed field checklists:
LucasZBaggiotto/app-store-review-skill and templetongroup/app-store-review.
