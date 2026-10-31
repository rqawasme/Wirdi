# Google Play listing

The text and answers for Wirdi's Play Console pages, drafted here so that they
are reviewed and versioned like everything else. Play Console is where they are
entered; nothing reads this file. When one changes in the Console, change it
here too.

[`RELEASING.md`](RELEASING.md) covers the release side: signing, uploads and
tracks.

## Store listing

*Grow users → Store presence → Main store listing.*

**App name** (30 characters at most)

> Wirdi: Daily Wird & Dhikr

Play's metadata policy rules out emoji, ALL CAPS, and claims such as "best" or
"#1" in the name. Plain *Wirdi* is fine too; the longer one is what people
search for.

**Short description** (80 at most)

> Daily wird, adhkar and Quran with a counter and a streak. Offline, no account.

**Full description** (4000 at most)

> Wirdi is a quiet companion for daily practice: the litanies you keep, the
> adhkar you say, and the Quran — with a counter that keeps your place and a
> tracker that shows the days you kept them.
>
> THE WIRDS
> Built in, each in Arabic with an English translation:
> • The wird of Imam al-Nawawi
> • The morning and evening adhkar
> • al-Wird al-Latif of Imam al-Haddad, morning and evening
> • Hizb al-Bahr of Imam al-Shadhili
> • Hizb al-Nasr, of Imam al-Haddad and of Imam al-Shadhili
> • Dala'il al-Khayrat, a part for each day of the week
> • The Wazifa ash-Shadhiliyya
> • Wird as-Sakran
> • Dua al-Nasiri
> • The Ratibs of Imam al-Haddad and of Habib Umar al-Attas
>
> MAKE YOUR OWN
> • Build collections from the library of adhkar, Sunnah duas and surahs
> • Write your own adhkar and add them to any collection
> • Choose how many times each one is said
>
> COUNT AND KEEP YOUR PLACE
> • Commit to a collection, on every day or on the days you choose, and it is
>   waiting on the home screen when it is due
> • A reminder at the time you choose, if you want one — and not on a day
>   you have already done it
> • Step through a wird one dhikr at a time, tapping to count, with a gentle
>   vibration as you go
> • A tasbih counter for everything else
>
> THE QURAN
> • All 114 surahs in Uthmani script, with the Saheeh International translation
>
> THE TRACKER
> • Days in a row, a calendar, and the weeks behind you — or turn it off
>
> PRIVATE BY DESIGN
> • No account, no ads, no tracking
> • No internet access at all: nothing you do leaves your phone
> • Light and dark themes, and Arabic and translation sizes you can adjust

**Category** — Lifestyle. **Tags** — pick the religion and spirituality ones
Play offers.

**Contact details** — an email address is required and is shown publicly on the
listing. A website is optional; the repository will do.

### Graphics

| Asset | Size | Where it comes from |
| --- | --- | --- |
| App icon | 512 × 512 PNG | `assets/icon/play_store_icon.png`, written by `tool/render_app_icons.py` |
| Feature graphic | 1024 × 500 PNG, no alpha | `assets/icon/play_feature_graphic.png`, written by the same script: the tasbih on the limestone cream over the voussoir rule. No text, since the app's name is beside it wherever Play shows it |
| Phone screenshots | 2 to 8, 16:9 or 9:16, 320–3840 px a side | `assets/store/01-home.png` to `08-dark.png`, written by `test/render_store_screenshots.dart`. Upload all eight, in that order |

The eight phone screenshots are posts rather than bare screens: a headline and
one line over the real app on a phone, 1080 × 1920 and 24-bit PNG with no
alpha, which is what Play needs for them to be eligible for its featured
placements. The screens are the app itself — pumped with the bundled fonts and
the real `content.db`, over a user database seeded with a few weeks of
somebody keeping their adhkar — so they show what a release build draws, with
no debug banner.

| # | Headline | Screen |
| --- | --- | --- |
| 1 | Your daily wird, waiting for you | Home: six commitments, three done |
| 2 | Tap anywhere to count | The wird player, part-way through a dhikr of ten |
| 3 | The great litanies, built in | Collections → Library |
| 4 | On the days you choose | The commit sheet: al-Kahf on Fridays, with a reminder |
| 5 | The Quran, verse by verse | Al-Fatiha in the reading view |
| 6 | A tasbih for everything else | The tasbih, 22 of a goal of 33 |
| 7 | See the days you kept | The tracker |
| 8 | Private by design | The wird player in dark |

Rendering them needs the content database built and synced first:

```bash
python3 content/scripts/build_content.py
tool/sync_content_asset.sh
flutter test test/render_store_screenshots.dart   # -> assets/store/*.png
```

The headlines are in the file beside the screens they caption; change the
copy there and rerun, rather than editing the PNGs. The home screen and the
tracker read today's date, so a rerun on another day shows other days.

## App content

*Policy and programs → App content.* Internal testing can go out before these
are done, but closed testing and production cannot, so finish every form before
starting the closed test.

| Form | Answer |
| --- | --- |
| Privacy policy | `https://github.com/rqawasme/Wirdi/blob/main/docs/PRIVACY.md` |
| Ads | No, the app does not contain ads |
| App access | All functionality is available without special access |
| Content rating | See below |
| Target audience | 13–15, 16–17 and 18 and over. See below |
| Data safety | See below |
| Government apps | No |
| Financial features | None |
| Health | None |
| News app | No |

### Data safety

- Does your app collect or share any of the required user data types? **No.**
- Is all of the user data collected by your app encrypted in transit? Not asked
  once the answer above is No.

That answer is true because the release manifest declares no `INTERNET`
permission, so the app cannot send anything anywhere. It declares two others,
both for reminders: `POST_NOTIFICATIONS`, to show them, and
`RECEIVE_BOOT_COMPLETED`, to keep them scheduled across a restart. Neither
collects or shares anything — a reminder is a local notification the phone
shows at a time the app gave it — so neither changes an answer on this form.
`test/app/android_manifest_test.dart` fails if any other permission is added.
Anybody adding one — for sync, anything — changes this form and
[`PRIVACY.md`](PRIVACY.md) in the same release.

### Content rating

The IARC questionnaire. Category: **Reference, News, or Educational** — the
closest fit for religious text. Every content question — violence, sexuality,
language, controlled substances, gambling — is No. There is no user-to-user
interaction, nothing is shared, and there are no purchases. The result should be
Everyone / PEGI 3.

### Target audience

Choosing any age group under 13 brings the app under the Families policy, with
its own review. Nothing in Wirdi would fail it, since there are no ads and no
data, but it is more review for no gain. **13 and over**, and "Could your store
listing unintentionally appeal to children?" — No.
