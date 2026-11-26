# Rahala — Game Design Document
## Vision
رحّالة — رحلة حول العالم is an original Arabic-first Android educational geography adventure for Arabic-speaking players, including children, teens and adults. Global scope, not USA-centric. A casual game with short missions, tactile feedback and discovery rather than an exam. Use Modern Standard Arabic (الفصحى المبسطة) throughout all player-facing screens, including error states. No literal English UI or copied competitor art.
## Core loop
Choose chapter → play 5–10 questions → immediate friendly feedback and a short fact → complete mission → earn stars/XP and unlock next mission → revisit mistakes and discover passport entries. No mandatory timer in learning mode; no punitive energy gate. Replay without losing earned stars or farming XP from identical completion events.
## Roadmap and content
Long-term target: 250 authored/generated validated levels, 195 countries under the common 193 UN member + 2 observer state convention, 3,000+ validated questions, eight modes. These are goals, not claims about the MVP.
Chapters: العالم العربي (1–30), إفريقيا (31–60), آسيا (61–90), أوروبا (91–120), أمريكا الشمالية (121–150), أمريكا الجنوبية (151–180), أوقيانوسيا (181–210), تحدي العالم (211–250). Arab world is a cross-continental learning chapter; countries can recur. Use stable IDs and separate chapter membership from continent classification. Add Antarctica, oceans and physical geography in later content. Start with familiar flags and capitals then introduce location, shape, mixed and optional speed challenges. Practice by chapter and mode after first mission.
## Play modes
1. خمن العلم — flag to country, four choices.
2. عواصم العالم — country to capital or reverse, four choices.
3. حدد الدولة — tap country on zoomable/pannable map; support accessible list alternative and tiny countries.
4. خمن الدولة من شكلها — accurate outline, four choices.
5. معالم العالم — landmark recognition with licensed assets.
6. ركب الخريطة — drag/drop or accessible tap alternative.
7. الجغرافيا الطبيعية — oceans, rivers, mountains, deserts.
8. تحدي السرعة — opt-in timed mixed questions.
## Mission rules
Start with 5 questions for early levels, 10 for normal levels; later use mixed modes and optional timers. 80% correct on first attempt passes; 80% earns 1 star, 90% 2 stars, 100% 3 stars (integer thresholds rounded up). Failed mission remains replayable. Immediate correct/incorrect indication using text, icon and color; show correct answer and fact before continuing. Persist mistakes by question ID and include them in review. XP: 10 per first-time correct mastery of a question, no duplicate rewards; best stars only. Keep the economy simple; no paywall or ads in MVP.
## Screens
Home: Continue adventure, chapter cards, quick practice, passport, settings. Chapter path: available/locked/completed missions and best stars. Quiz: progress, prompt, visual, large choices, feedback and next. Results: score, stars, retry/continue. Passport: collectible stamps by country with flag, name, capital and one fact. Settings: sound, reduced motion, reset progress with confirmation, credits. Navigation and dialogs fully RTL.
## Visual direction
Original premium travel-adventure style: deep navy #102F49, turquoise #15A89A, warm cream #FFF6E7, gold #F4B744, coral #E96B62. Use coherent rounded cards, friendly original globe/compass/passport motifs, subtle shadows, smooth 150–300ms transitions, satisfying feedback, minimal text, generous touch areas (48dp min). Do not use emoji as the sole icon system or render national flags as emoji when accurate SVG assets exist. Use bundled licensed Arabic font (e.g. Noto Sans Arabic or Cairo) and record license. Respect RTL layout but do not mirror geographic maps or flags. Test Arabic shaping, long country names, mixed numerals, small screens, large text, contrast and reduced motion. No fake UI placeholders or nonfunctional buttons.
## Geography data policy
Bundle versioned offline UTF-8 data. Country records: stable ID, Arabic name, aliases, capital(s) with notes where needed, continent(s), chapter membership, flag asset, optional map feature ID, verified short Arabic facts and source/asset licenses. Use reliable geographic sources and document them. Distinguish countries and territories; handle disputed boundaries, alternative names, transcontinental countries and multiple capitals sensitively and consistently; avoid asking questions with disputed or ambiguous answers. Never assume all maps are politically neutral; document map convention and source. Avoid current population questions without dated sources. No generated/invented geography facts. Use accurate, licensed flags/maps, not approximations. Validate IDs, unique answer choices, one correct answer, references, source provenance and assets. Review Arabic spelling.
## MVP acceptance scope
Android-only Flutter vertical slice: polished home, chapter path, quiz, results, passport, settings; at least 12 missions using flag and capital modes; at least 30 verified countries across multiple continents with bundled licensed flags; no mandatory network, no account, no ads, no external analytics. Local progress survives restart. Include a map mode only if reliable licensed vector data and hit testing are available; otherwise do not expose it until implemented. Design the content pipeline for all 195 countries, but clearly mark unimplemented content as unavailable rather than implying coverage. Later expand to map, shape, landmarks, physical geography, full world catalog, optional daily challenge.
## Quality gate
A complete end-to-end playable loop on a small Android screen, no overflow or dead controls; all accessible labels Arabic; offline cold start and progress persistence; automated data, quiz, rewards, unlock and widget tests; format, analyze, test and Android debug build pass in CI. No placeholder questions or fabricated test results. Real device playtest by owner before expansion.
## Future monetization
Optional non-intrusive premium content; evaluate age audience and applicable Google Play Families/privacy requirements before ads, analytics or accounts. No monetization SDKs in MVP.
