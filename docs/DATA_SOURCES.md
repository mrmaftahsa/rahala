# Geography sources and conventions

## Country catalog

[The version 2 catalog](../assets/data/geography.v2.json) contains the 193 United Nations member states and two observer states. Palestine and the Holy See are included. The Vatican City geometry represents the Holy See's territorial setting and is labeled الفاتيكان. Other territories and disputed entities can appear in the map's background and are outside the selectable country catalog. [UN members](https://www.un.org/en/about-us/member-states) · [Observer states](https://www.un.org/en/about-us/non-member-states)

Country IDs are lowercase ISO 3166-1 alpha-2 codes. The game uses UN M49 grouping as a starting point for its adventure paths. Central America and the Caribbean travel with North America. The Arab world path is a separate collection of the 22 Arab League members. Catalog filters include the second geographic region for Egypt, Russia, Türkiye, Kazakhstan, Indonesia, Azerbaijan, and Georgia. Europe and Asia share several conventional continental boundaries. The catalog places Cyprus in Western Asia geographically. [UN M49](https://unstats.un.org/unsd/methodology/m49/) · [Arab League](https://www.britannica.com/topic/Arab-League)

Arabic names come from Natural Earth's Arabic labels with editorial corrections and optional aliases. Capital answers use Arabic Natural Earth populated-place labels where they match the capital recorded in the country profile, with editorial overrides for local spelling, current seats, and special cases. The country-code input supplies ISO/FIPS cross-references and region groupings. Its maintainers dedicate their arrangement and scripts under PDDL 1.0. GeoNames is credited for secondary capital cross-checks. [Pinned country-code input](https://github.com/datasets/country-codes/blob/2d84034a0cae19ea5444b78c2131304a5c7f4bb9/data/country-codes.csv) · [GeoNames CC BY 4.0](https://www.geonames.org/export/)

Each country's `source` gives the path of its individual profile in the pinned World Factbook archive. Facts are editorial Arabic translations and summaries of the linked profiles' geography and government fields. The 35 original country names, capital answer texts, flag paths, and all first-edition question and mission IDs are preserved. [World Factbook profile archive](https://github.com/factbook/factbook.json/tree/144d6977b2b01ac1cbd220de754c0a005616760b) · [CC0 dedication](../assets/data/LICENSE-factbook.md)

Encyclopedia entries explain capital cases involving multiple seats, an unsettled status, a planned move, or a city without official capital status. Such cases are excluded from scored capital questions and distractors. The editorial overrides cover Gitega, Astana, Dodoma, Ngerulmud, Sri Lanka's legislative capital, and Equatorial Guinea's January 2026 relocation to Ciudad de la Paz. Chile retains Santiago as the capital and notes that Valparaíso hosts the legislature. [Burundi profile](https://github.com/factbook/factbook.json/blob/144d6977b2b01ac1cbd220de754c0a005616760b/africa/by.json) · [Current GeoNames country reference](https://download.geonames.org/export/dump/countryInfo.txt) · [Equatorial Guinea government press](https://www.guineaecuatorialpress.com/)

## Atlas and boundaries

The interactive atlas uses Natural Earth 1:10m Admin 0 Countries v5.1.2. The app bundles simplified vector polygon rings, including holes, in an equirectangular projection. A country has a geographic anchor on its source geometry. The app renders shapes and performs hit testing on the device. Small polygons have map markers and are selectable from a searchable list. Silhouettes re-center components around the antimeridian when needed. [Natural Earth release](https://github.com/nvkelso/natural-earth-vector/tree/f1890d9f152c896d250a77557a5751a93d494776/10m_cultural) · [Public-domain terms](https://www.naturalearthdata.com/about/terms-of-use/) · [Bundled attribution](../assets/data/NATURAL-EARTH.txt)

Natural Earth's standard layer depicts de facto administration. Display is for geographical education. An Arabic note about the convention appears next to the atlas and country detail maps. The catalog preserves background geometry for dependent and disputed areas. Where multiple features reuse a country code, the exact ISO code, home-part flag, and land area identify its primary polygon. Simplification prioritizes browsing and game performance. Fine coastlines and boundary survey detail are outside atlas scale.

The outline and tap-on-map quizzes skip affected entries where a scored boundary answer could imply recognition of a disputed claim. These are Armenia, Azerbaijan, China, Cyprus, Georgia, Guyana, India, Israel, Moldova, Morocco, Pakistan, Palestine, Russia, Serbia, Somalia, South Sudan, Sudan, Ukraine, and Venezuela. Players can view each entry in the atlas and learn its flag and any eligible capital.

## Flags and typography

- All 195 flags are 600-pixel-wide PNG exports of pinned country-flags SVG originals. The project identifies its source artwork from Wikimedia Commons as public domain and notes national flag use rules. Inkscape preserves each asset's original proportions. [Pinned SVG originals](https://github.com/hampusborgos/country-flags/tree/c09927e63705529bbf59ca6684cd9b23225dddad/svg) · [Bundled attribution](../assets/flags/SOURCE.txt)
- **Noto Sans Arabic** uses static instances of the pinned variable font at normal width and weights 500 and 800. The two faces retain the SIL Open Font License 1.1. [Pinned font](https://github.com/google/fonts/tree/6ebe737e44fd64ee736bbc6feed6136a6dbfd222/ofl/notosansarabic) · [Bundled OFL](../assets/fonts/OFL.txt)
- The globe, compass, and launcher artwork were created for Rahala. The UI also uses the Material icon font. [Material Icons](https://github.com/google/material-design-icons)
- Flutter, Flutter Localizations, and **shared_preferences** use BSD-3-Clause. The Android preferences backend stores a single versioned snapshot in Jetpack DataStore. [Package license](https://pub.dev/packages/shared_preferences/license)

## Rebuilding the bundled content

The Android build uses committed assets and runs offline after build dependencies are installed. To regenerate geography assets in a cloud workspace, prepare a scratch input directory with:

- `country-codes.csv` from the pinned input above.
- Unpacked `factbook.json-<commit>` and `country-flags-<commit>` source archives from the revisions above.
- `ne_10m_admin_0_countries.json` and `ne_10m_populated_places.json` converted with `ogr2ogr -f GeoJSON` from the corresponding 1:10m shapefiles and sidecars in Natural Earth v5.1.2.

Run `python tools/geography/build.py INPUT_DIRECTORY --flags` with Shapely 2.2 and Inkscape. The checked-in Arabic editorial facts and original catalog are generator inputs. Omit `--flags` when flags are already rendered. Pin upstream source revisions for reproducibility and review changes in capital notes before regenerating assets.

Preserve every published country, question, and mission ID. Phase 2 uses stored country IDs and new `location.country` and `outline.country` question IDs. New routes use the frozen `chapter.routeNN.mode` IDs in the committed catalog. When expanding a route, append stable assignments and keep the content associated with earlier IDs. Catalog tests validate exact coverage, source references, selectable geometry, flags, distinct answers, and old checkpoints.
