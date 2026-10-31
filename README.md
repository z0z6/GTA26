# Uciekaj przed windykatorem

Gra w stylu GTA2 (widok z góry, 3D) na prawdziwym układzie miasta: Maków Mazowiecki z danych OpenStreetMap.
Uciekasz przed windykatorami, zbierasz monety, rzucasz w pościg czym popadnie i omijasz absurdy samorządowe.
Silnik: Godot 4.4 (GDScript, renderer Compatibility). Cel: Android.

## Co jest w grze

- Oświetlenie nocne: kolorowa mapa świateł (`scripts/lightmap.gd`) z latarniami, stożkami reflektorów aut, tylnymi światłami i błyskami; trzy pory doby (dzień, zmierzch, noc), bloom (`shaders/bloom.gdshader`, `scripts/postfx.gd`) oraz mokry asfalt z odbiciami świateł i kałużami (`shaders/ground.gdshader`).
- Podłoże rysowane shaderem (gładkie granice terenów, chodniki, oznaczenia dróg, woda), budynki z wielokątów OSM
  z elewacjami, dachami spadzistymi i płaskimi, drzewa, latarnie, tryb nocny.
- Postacie 3D z animacją: gracz, 4 typy wierzycieli, przechodnie z reakcjami na sytuację (auta, pościg, rzucane przedmioty, wydarzenia).
- Ruch uliczny: 9 typów nadwozia, losowe kolory i zmyślone marki.
- Obrona: rzucanie 7 rodzajów przedmiotów (w tym wybuchowa Petarda), zbieranie ich z toreb.
- Efekty: wybuchy (ogień, iskry, żar, dym, fala uderzeniowa, przypalenie ziemi), ślady opon i dym spod kół przy hamowaniu awaryjnym aut, błyski świateł (`scripts/effects.gd`).

## Uruchomienie

1. Otwórz projekt w Godot 4.4.x i naciśnij F5.
2. Sterowanie: strzałki/WASD (lub przeciąganie palcem), Shift = sprint, Spacja = rzut, N = dzień/zmierzch/noc, Enter = start, kółko myszy / +/− / szczypanie = przybliżenie.

## Testy (bez okna, jak w CI)

```
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . -- --autoplay=40 --steps=10
```

Podgląd do zrzutów (wymaga renderera, np. xvfb + opengl3):
`godot --rendering-driver opengl3 --path . -- --shot=plik.png --at=533,441 [--dusk|--night] [--autoplay=20 --steps=10]`

## Android

Preset w `export_presets.cfg`, workflow `.github/workflows/android.yml` (Actions → Android build → Run workflow).
Wymagane ustawienie projektu `import_etc2_astc=true` jest już włączone.

## Web (przeglądarka)

Preset "Web" w `export_presets.cfg` (bez wątków, więc nie wymaga specjalnych nagłówków serwera), workflow
`.github/workflows/web.yml` (Actions → Web build → Run workflow) publikuje grę na GitHub Pages.
Wymagane jednorazowo: Settings → Pages → Source: **GitHub Actions**.
Uwaga: `index.wasm` ma ok. 44 MB bez kompresji, więc pierwsze wczytanie jest wolniejsze.

## Oświetlenie (jak dodać własne światło)

`scripts/lightmap.gd` rysuje co klatkę małą mapę świateł (SubViewport 64×64 kafle wokół kamery), którą próbkują shadery
terenu, budynków i obiektów. W `main.gd` → `_update_lights()` wystarczy wywołać:

```
lights.point(pozycja, promień, Color(...), jasność)                      # latarnia, blask
lights.cone(pozycja, kierunek, zasięg, połowa_szerokości, Color(...), jasność)   # reflektor
lights.flash(pozycja, Color(...), promień, czas)                          # krótki błysk (trafienie, uderzenie)
```

Bloom działa wieczorem i w nocy; na słabszym telefonie wyłączysz go jedną stałą `ENABLED` w `scripts/postfx.gd`
(siła: `BLOOM_STRENGTH`). Wilgotność jezdni to uniform `wetness` materiału terenu (0 = sucho, 1 = mokro; w dzień bez efektu).

Nastrój nocy reguluje się w `shaders/common.gdshaderinc`: stałe `AMB_DUSK` i `AMB_NIGHT` (światło otoczenia)
oraz `lamps_on()` (kiedy zapalają się latarnie i okna).

## Efekty (wybuchy, ślady opon)

`scripts/effects.gd` rysuje trzy warstwy MultiMesh (cząsteczki świecące, dym, decale na ziemi), więc cały system to 3 wywołania rysowania.
Z kodu gry wywołujesz:

```
fx.explosion(pozycja, promień)          # pełny wybuch + przypalenie + błysk w mapie świateł + drżenie kamery
fx.spark_burst(pozycja, ile, szybkość)  # garść iskier
fx.smoke_puff(pozycja, ...)             # chmurka dymu
fx.skid_segment(a, b)                   # odcinek śladu opony
fx.car_impact(auto, prędkość)           # nagłe zatrzymanie auta: ślad hamowania, iskry, dym
```

Ślady opon pojawiają się same, gdy auto hamuje awaryjnie (`car.gd`). Wybuch uruchamia Petarda (`_detonate()` w `main.gd`):
ogłusza wierzycieli, płoszy przechodniów, zatrzymuje pobliskie auta, a trafiony własną petardą gracz dostaje 300 zł kary.
Podgląd bez grania: `-- --shot=plik.png --at=516,447 --autoplay=1 --steps=1 --fxdemo=522,448` (wybuch i ślady w podanym miejscu).

## Dane

- `data/makow_grid.png`: siatka 1074×1001 kafli (R = klasa, G = klasa podłoża, B = pokrycie budynkiem).
- `data/buildings.json`: obrysy budynków (kafle), piętra, typ, dach.
- `tools/`: skrypty Pythona (w kolejności: `stitch`/`solve`/`mosaic`, `classify`, `regularize`, `buildings2`), z których powstały (scalanie zrzutów, klasyfikacja kolorów; zrzutów źródłowych nie ma w repo).

## Licencje i atrybucja

Układ ulic, budynków i terenów: © autorzy OpenStreetMap, licencja ODbL (https://www.openstreetmap.org/copyright).
Atrybucja jest widoczna w grze. Postacie, marki samochodów i nazwy są zmyślone.
