# Data sources and licenses

## Geography catalog

The MVP bundles an offline UTF-8 catalog in [geography.v1.json](../assets/data/geography.v1.json). It includes 35 countries across six continents and 70 reusable flag and capital questions. Each country record links its capital and Arabic fact to a specific profile path in the [pinned World Factbook archive](https://github.com/factbook/factbook.json/tree/144d6977b2b01ac1cbd220de754c0a005616760b). The Arabic facts are concise translations or summaries of the profile's **Geography** or **Government** fields. The archive uses CC0 1.0 and reproduces public-domain World Factbook data. The full dedication is bundled with the app. [Archive license](../assets/data/LICENSE-factbook.md)

Country IDs are lowercase ISO 3166-1 alpha-2 codes. The archive uses older FIPS file names, so `source` records its actual path. Chapter membership is assigned independently of continent. The Arab world is a cross-continental chapter. Egypt is tagged with both Africa and Asia because of Sinai. France is tagged with Europe and its fact is explicitly about metropolitan France. Central America and the Caribbean are grouped with North America. Oceania is the chapter and catalog region for Australia and its neighboring Pacific countries.

The 35 countries are a subset of the 193 United Nations members and two observer states convention described in the design. Territories are outside this edition. The application contains no political boundary maps. Capital quiz records use a single generally recognized answer. The Chile entry notes that Santiago is the capital and Valparaíso holds the national legislature. Future records with ambiguous answers should be excluded from quizzes until the data and question format can disambiguate them.

## Artwork and typography

- The national flags are 600-pixel PNG renders of [pinned SVG originals](https://github.com/hampusborgos/country-flags/tree/c09927e63705529bbf59ca6684cd9b23225dddad/svg), sourced by **country-flags** from Wikimedia Commons. The upstream project identifies this artwork as public-domain and notes that use of some flags may be regulated. Inkscape rendered each original view box without changing proportions, colors, or orientation. [Bundled attribution](../assets/flags/SOURCE.txt)
- **Noto Sans Arabic** is distributed under the SIL Open Font License 1.1. The two bundled fonts are static instances of the [pinned variable font](https://github.com/google/fonts/tree/6ebe737e44fd64ee736bbc6feed6136a6dbfd222/ofl/notosansarabic), instantiated at normal width and weights 500 and 800 with FontTools. [Bundled OFL](../assets/fonts/OFL.txt)
- The compass, globe illustration, and launcher artwork were created for Rahala. The application uses the Material icon font distributed with Flutter. [Material Icons](https://github.com/google/material-design-icons)
- Flutter and its localization library are BSD-3-Clause. The additional runtime package, **shared_preferences**, is BSD-3-Clause and uses Jetpack DataStore on Android for the versioned progress snapshot. [Package license](https://pub.dev/packages/shared_preferences/license)

## Extending the catalog

Add a sourced country record and its flag, then reference its ID in one or more missions. Missions contain 5–10 questions. Each mission declares country IDs separately for its flag and capital questions. Add new missions with stable IDs prefixed by the chapter ID. Questions use `mode.country` IDs across missions, practice, and review. Preserve IDs so existing stars, experience, and stamps remain attached to the same content.

Running `flutter test` validates the catalog, flag decoding, mission references, distinct choices, stable question IDs, deterministic seeded generation, and scoring. New facts and capital answers still need source and Arabic editorial review before inclusion.
