"""Build the offline catalog and simplified Natural Earth atlas from pinned sources.

The input directory and commands are documented in docs/DATA_SOURCES.md.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import csv
import json
from pathlib import Path
import subprocess

from shapely import make_valid
from shapely.geometry import Polygon, shape


ROOT = Path(__file__).resolve().parents[2]
ARAB = set("ae bh dj dz eg iq jo km kw lb ly ma mr om ps qa sa sd so sy tn ye".split())
TRANS = {
    "az": "europe", "eg": "asia", "ge": "europe", "id": "oceania",
    "kz": "europe", "ru": "asia", "tr": "europe",
}
UNQUIZZED_MAP = set("am az cn cy ge gy il in ma md pk ps rs ru sd so ss ua ve".split())
REGION_NAMES = {
    "Northern Africa": "شمال إفريقيا", "Western Africa": "غرب إفريقيا",
    "Middle Africa": "وسط إفريقيا", "Eastern Africa": "شرق إفريقيا",
    "Southern Africa": "جنوب إفريقيا", "Central Asia": "آسيا الوسطى",
    "Eastern Asia": "شرق آسيا", "Western Asia": "غرب آسيا",
    "Southern Asia": "جنوب آسيا", "South-eastern Asia": "جنوب شرق آسيا",
    "Eastern Europe": "شرق أوروبا", "Northern Europe": "شمال أوروبا",
    "Southern Europe": "جنوب أوروبا", "Western Europe": "غرب أوروبا",
    "Northern America": "شمال أمريكا الشمالية", "Central America": "أمريكا الوسطى",
    "Caribbean": "الكاريبي", "South America": "أمريكا الجنوبية",
    "Australia and New Zealand": "أستراليا ونيوزيلندا",
    "Melanesia": "ميلانيزيا", "Micronesia": "ميكرونيزيا", "Polynesia": "بولينيزيا",
}
CHAPTER_NAMES = {
    "africa": "إفريقيا", "asia": "آسيا", "europe": "أوروبا",
    "north_america": "أمريكا الشمالية", "south_america": "أمريكا الجنوبية",
    "oceania": "أوقيانوسيا", "arab": "العالم العربي",
}
MAIN_REGIONS = {
    "Africa": "africa", "Asia": "asia", "Europe": "europe", "Oceania": "oceania",
}
NAME_EDITS = {
    "ba": "البوسنة والهرسك", "bs": "جزر البهاما", "cf": "جمهورية إفريقيا الوسطى",
    "cv": "الرأس الأخضر", "do": "جمهورية الدومينيكان", "ie": "أيرلندا",
    "om": "عُمان", "ps": "فلسطين", "st": "ساو تومي وبرينسيبي",
    "va": "الفاتيكان", "vc": "سانت فنسنت والغرينادين", "za": "جنوب إفريقيا",
}
CAPITAL_EDITS = {
    "be": "بروكسل", "bi": "غيتيغا", "bj": "بورتو نوفو", "ci": "ياموسوكرو",
    "gq": "سيوداد دي لا باز", "kw": "مدينة الكويت", "kz": "أستانا",
    "lk": "سري جاياواردنابورا كوتي", "mk": "سكوبيه", "nr": "منطقة يارين",
    "ps": "القدس الشرقية", "pw": "نغيرولمود", "ss": "جوبا",
    "td": "نجامينا", "tz": "دودوما", "va": "مدينة الفاتيكان", "za": "بريتوريا",
}
# Capital quizzes exclude countries whose answer needs a political or legal qualifier.
CAPITAL_NOTES = {
    "bj": "بورتو نوفو العاصمة الرسمية، وتستضيف كوتونو مقر الحكومة.",
    "bo": "سوكري العاصمة الدستورية، وتستضيف لاباز مقر الحكومة.",
    "ch": "برن المدينة الاتحادية ومقر الحكومة الاتحادية.",
    "ci": "ياموسوكرو العاصمة الرسمية، وتضم أبيدجان عددًا من الهيئات الحكومية.",
    "gq": "أُعلنت سيوداد دي لا باز العاصمة في يناير ٢٠٢٦، وكانت مالابو العاصمة السابقة.",
    "id": "جاكرتا مقر العاصمة الحالي في هذه النسخة، ومشروع انتقال العاصمة إلى نوسانتارا قيد التنفيذ.",
    "il": "تعدّ إسرائيل القدس عاصمتها، ووضع المدينة محلّ نزاع دولي.",
    "ki": "جنوب تاراوا هو المركز الإداري ويضم مقار الحكومة.",
    "lk": "سري جاياواردنابورا كوتي مقر السلطة التشريعية، وتضم كولومبو مقار حكومية.",
    "my": "كوالالمبور العاصمة، وتضم بوتراجايا مقرّ الإدارة الاتحادية.",
    "nl": "أمستردام عاصمة البلاد، وتستضيف لاهاي الحكومة والبرلمان.",
    "nr": "ليس لناورو عاصمة رسمية. توجد مقارّ الحكومة في منطقة يارين.",
    "ps": "تعلن دولة فلسطين القدس الشرقية عاصمةً لها، وتوجد مقارّ الإدارة الفلسطينية في رام الله.",
    "pw": "تقع نغيرولمود، مقرّ الحكومة، في ولاية ميليكيوك.",
    "sz": "مبابان العاصمة الإدارية، ولوبامبا العاصمة الملكية والتشريعية.",
    "tz": "دودوما العاصمة، ودار السلام أكبر مدن البلاد ومركزها التجاري.",
    "ye": "صنعاء العاصمة الدستورية. تتخذ الحكومة المعترف بها دوليًا عدن مقرًا مؤقتًا.",
    "za": "بريتوريا مقر الحكومة، وكيب تاون مقر البرلمان، وبلومفونتين مقر محكمة الاستئناف العليا.",
}
UNQUIZZED_CAPITAL = set("bj bo ch ci id il lk my nl nr ps sz ye za".split())
ALIASES = {
    "ae": ["الإمارات"], "cv": ["كابو فيردي"], "cz": ["تشيكيا"],
    "gb": ["بريطانيا"], "gq": ["غينيا الإستوائية"], "ie": ["إيرلندا"],
    "mk": ["مقدونيا"], "mm": ["بورما"], "ps": ["دولة فلسطين"],
    "tl": ["تيمور-ليشتي"], "va": ["الكرسي الرسولي"],
    "ci": ["كوت ديفوار"], "sz": ["سوازيلاند"],
}
MODES = ("flag", "capital", "location", "outline")
SOUTH_AMERICA = set("ar bo br cl co ec gy pe py sr uy ve".split())
REGIONAL_ORDER = {
    "africa": ["Northern Africa", "Western Africa", "Middle Africa", "Eastern Africa", "Southern Africa"],
    "asia": ["Western Asia", "Central Asia", "Southern Asia", "Eastern Asia", "South-eastern Asia"],
    "europe": ["Western Europe", "Northern Europe", "Southern Europe", "Eastern Europe"],
    "north_america": ["Northern America", "Central America", "Caribbean"],
    "south_america": ["South America"],
    "oceania": ["Australia and New Zealand", "Melanesia", "Polynesia", "Micronesia"],
    "arab": ["Northern Africa", "Eastern Africa", "Western Africa", "Western Asia"],
}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def source_polygons(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "Polygon":
        return [geom]
    if hasattr(geom, "geoms"):
        return [p for component in geom.geoms for p in source_polygons(component)]
    return []


def ring_coords(ring):
    pts = list(dict.fromkeys((round(x * 1000), round(y * 1000)) for x, y in list(ring.coords)[:-1]))
    return [value for point in pts for value in point] if len(pts) >= 3 else []


def map_shape(feature, country_id):
    geometry = make_valid(shape(feature["geometry"]))
    parts = sorted(source_polygons(geometry), key=lambda polygon: -polygon.area)
    if not parts:
        raise ValueError(feature["properties"]["NE_ID"])
    rings = []
    inside = None
    for part in parts:
        if part.area < 0.000015 and part is not parts[0]:
            continue
        simple = part.simplify(min(.045, (part.area ** .5) / 28), preserve_topology=True)
        exterior = ring_coords(simple.exterior)
        if not exterior:
            continue
        holes = [coords for ring in simple.interiors if (coords := ring_coords(ring))]
        rings.extend([exterior, *holes])
        if inside is None:
            def pairs(coords):
                return list(zip(coords[::2], coords[1::2]))
            snapped = make_valid(Polygon(pairs(exterior), [pairs(hole) for hole in holes]))
            polygons = source_polygons(snapped)
            if polygons:
                inside = max(polygons, key=lambda polygon: polygon.area).representative_point()
    assert rings and inside is not None, feature["properties"]["NE_ID"]
    return [country_id, round(inside.x, 3), round(inside.y, 3), rings]


def group_questions(ids, max_len=9):
    """Balance adjacent destinations without short filler levels."""
    groups = (len(ids) + max_len - 1) // max_len
    for index in range(groups):
        yield ids[len(ids) * index // groups:len(ids) * (index + 1) // groups]


def missions_for(countries, legacy):
    levels = [dict(level, legacy=True) for level in legacy]
    for chapter, order in REGIONAL_ORDER.items():
        chapter_countries = [row for row in countries if chapter in row["chapters"]]
        regional_rank = {region: index for index, region in enumerate(order)}
        chapter_countries.sort(key=lambda country: (regional_rank.get(country["_subregion"], len(order)), country["id"]))
        new_levels = []
        for mode in MODES:
            eligible = [row for row in chapter_countries if supports(row, mode)]
            # Reserve replay for the world challenge. A small chapter may need
            # some introductory countries to keep its second round at five.
            previous = {id for level in legacy if level["chapter"] == chapter for id in level.get(mode, [])}
            fresh = [row for row in eligible if row["id"] not in previous]
            if len(fresh) >= 5:
                eligible = fresh
            elif fresh:
                eligible = fresh + [row for row in eligible if row["id"] in previous][:5-len(fresh)]
            else:
                continue
            for index, group in enumerate(group_questions(eligible)):
                regions = {row["region"] for row in group}
                region = group[0]["region"] if len(regions) == 1 else CHAPTER_NAMES[chapter]
                new_levels.append((index, MODES.index(mode), {
                    "id": f"{chapter}.route{index + 1:02}.{mode}",
                    "chapter": chapter, "title": region,
                    "difficulty": "mastery" if mode == "outline" or index >= 3 else "exploration",
                    mode: [row["id"] for row in group],
                }))
        levels.extend(level for _, _, level in sorted(new_levels))
    world_batches = [
        ("بين المحيطين", "pt ca fj cl jp us au pe nz ph"),
        ("مدن على الأنهار", "iq eg fr hu th bd gh vn ar cz"),
        ("طرق عبر الجبال", "ma np ch et af ge ua bo kg tj"),
        ("عبر خط الاستواء", "ec co ga ug ke id br ki st mv"),
        ("محطّات الجزر", "mg mu is cu jm bb sg to pg lk"),
        ("من المتوسط إلى البلطيق", "es it gr tn tr si hr ee fi dk"),
        ("سهوب وصحارى", "mn kz na bw tm ne mr tn uz jo"),
        ("الرحلة الكبرى", "mx kr ke ad bz gy pw bs ao de"),
    ]
    by_id = {row["id"]: row for row in countries}
    for index, (title, route) in enumerate(world_batches, 1):
        level = dict(id=f"world.expedition{index:02}", chapter="world", title=title, difficulty="mastery")
        for offset, country_id in enumerate(route.split()):
            country = by_id[country_id]
            mode = next(MODES[(offset + shift) % 4] for shift in range(4)
                        if supports(country, MODES[(offset + shift) % 4]))
            level.setdefault(mode, []).append(country_id)
        assert len(level.keys() & set(MODES)) >= 3
        levels.append(level)
    assert len(levels) >= 100, len(levels)
    all_questions = {(mode, country["id"]) for country in countries for mode in MODES if supports(country, mode)}
    covered = {(mode, country) for level in levels for mode in MODES for country in level.get(mode, [])}
    assert all_questions == covered, sorted(all_questions - covered)
    assert all(5 <= sum(len(level.get(mode, [])) for mode in MODES) <= 10 for level in levels)
    return levels


def supports(country, mode):
    if mode == "capital":
        return country.get("capitalQuiz", True)
    if mode in ("location", "outline"):
        return country.get("mapQuiz", True)
    return True


def build(inputs, flags):
    previous = load(ROOT / "test/fixtures/geography.v1.json")
    originals = {country["id"]: country for country in previous["countries"]}
    facts = dict(line.split("|", 1) for line in Path(__file__).with_name("facts.txt").read_text().splitlines())
    with (inputs / "country-codes.csv").open() as handle:
        rows = {row["ISO3166-1-Alpha-2"].lower(): row for row in csv.DictReader(handle)
                if row["ISO3166-1-Alpha-2"] and
                (row["is_independent"] == "Yes" or row["ISO3166-1-Alpha-2"] == "PS")
                and row["ISO3166-1-Alpha-2"] != "TW"}
    assert len(rows) == 195 and len(facts) == 160 and set(facts) == rows.keys() - originals.keys()

    countries_layer = load(inputs / "ne_10m_admin_0_countries.json")["features"]
    by_iso = {}
    for feature in countries_layer:
        p = feature["properties"]
        iso = p["ISO_A2_EH"].lower()
        if iso in rows:
            by_iso.setdefault(iso, []).append(feature)
    # Natural Earth reuses ISO_A2_EH for a few dependent/disputed polygons.
    # Exact ISO_A2, home part and area select the actual country feature.
    primary = {iso: max(matches, key=lambda f: (
        f["properties"]["ISO_A2"].lower() == iso,
        f["properties"]["HOMEPART"] == 1, shape(f["geometry"]).area,
    )) for iso, matches in by_iso.items()}
    assert set(rows) == set(primary)
    primary_ids = {feature["properties"]["NE_ID"]: iso for iso, feature in primary.items()}
    places = load(inputs / "ne_10m_populated_places.json")["features"]
    capitals = {}
    for feature in places:
        p = feature["properties"]
        iso = p["ISO_A2"].lower()
        if p["ADM0CAP"] == 1 and iso in rows and p["NAME_AR"]:
            capitals.setdefault(iso, p["NAME_AR"])
    capitals.update(CAPITAL_EDITS)

    archive = next(inputs.glob("factbook.json-*"))
    profiles = {f.stem: f.relative_to(archive).as_posix() for f in archive.glob("*/*.json") if len(f.stem) == 2}
    catalog = []
    for iso in [*originals, *sorted(rows.keys() - originals.keys())]:
        row = rows[iso]
        ne = primary[iso]["properties"]
        chapter = MAIN_REGIONS.get(row["Region Name"])
        if row["Region Name"] == "Americas":
            chapter = "south_america" if iso in SOUTH_AMERICA else "north_america"
        assert chapter
        subregion = row["Intermediate Region Name"] or row["Sub-region Name"]
        continents = [chapter] + ([TRANS[iso]] if iso in TRANS else [])
        record = dict(originals.get(iso, {}))
        if not record:
            fips = {"ps": "we", "rs": "ri"}.get(iso, row["FIPS"].lower())
            record = dict(
                id=iso, name=NAME_EDITS.get(iso, ne["NAME_AR"]), capital=capitals[iso],
                aliases=ALIASES.get(iso, []), flag=f"assets/flags/{iso}.png",
                fact=facts[iso], source=profiles[fips],
            )
        record.update(continents=continents, chapters=[chapter] + (["arab"] if iso in ARAB else []),
                      region=REGION_NAMES[subregion], _subregion=subregion)
        if iso in CAPITAL_NOTES:
            record["capitalNote"] = CAPITAL_NOTES[iso]
        if iso in UNQUIZZED_CAPITAL:
            record["capitalQuiz"] = False
        if iso in UNQUIZZED_MAP:
            record["mapQuiz"] = False
        catalog.append(record)

    levels = missions_for(catalog, previous["missions"])
    for record in catalog:
        del record["_subregion"]
    data = ROOT / "assets/data"
    (data / "geography.v2.json").write_text(
        json.dumps(dict(schemaVersion=2, countries=catalog, missions=levels), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    atlas = [map_shape(feature, primary_ids.get(feature["properties"]["NE_ID"]))
             for feature in countries_layer]
    (data / "world.v1.json").write_text(json.dumps(dict(version=1, shapes=atlas), separators=(",", ":")) + "\n")
    if flags:
        originals_path = next(inputs.glob("country-flags-*")) / "svg"
        def rasterize(iso):
            destination = ROOT / f"assets/flags/{iso}.png"
            subprocess.run(["inkscape", str(originals_path / f"{iso}.svg"), "--export-width=600",
                            f"--export-filename={destination}"], check=True, capture_output=True)
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(rasterize, sorted(rows.keys() - originals.keys())))
    print(f"{len(catalog)} countries, {len(levels)} missions, {len(atlas)} map features")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_directory", type=Path)
    parser.add_argument("--flags", action="store_true", help="Render the new flags from SVG using Inkscape")
    arguments = parser.parse_args()
    build(arguments.input_directory, arguments.flags)
