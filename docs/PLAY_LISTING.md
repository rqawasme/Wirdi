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
| Feature graphic | 1024 × 500 PNG or JPEG | To make. The tasbih on the limestone cream, `#FBF6EC`, reads well; no text needed |
| Phone screenshots | 2 to 8, 16:9 or 9:16, 320–3840 px a side | From a phone: Home with a commitment, the wird player mid-count, a surah, the tracker, the collections list |

Screenshots from a release build on a real phone look like what people will
get: no debug banner, and the real fonts.

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

That answer is true because the release manifest declares no permissions, not
even `INTERNET`, so the app cannot send anything anywhere.
`test/app/android_manifest_test.dart` fails if a permission is added. Anybody
adding one — for reminders, sync, anything — changes this form and
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
