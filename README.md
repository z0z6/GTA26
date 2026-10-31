# Uciekaj przed windykatorem

Gra w stylu GTA2 (widok z góry, 3D) na prawdziwym układzie miasta: Maków Mazowiecki z danych OpenStreetMap.
Uciekasz przed windykatorami, zbierasz monety, rzucasz w pościg czym popadnie i omijasz absurdy samorządowe.
Silnik: Godot 4.4 (GDScript, renderer Compatibility). Cel: Android.

## Co jest w grze

- Oświetlenie nocne: kolorowa mapa świateł (`scripts/lightmap.gd`) z latarniami, stożkami reflektorów aut, tylnymi światłami i błyskami; trzy pory doby (dzień, zmierzch, noc).
- Podłoże rysowane shaderem (gładkie granice terenów, chodniki, oznaczenia dróg, woda), budynki z wielokątów OSM
  z elewacjami, dachami spadzistymi i płaskimi, drzewa, latarnie, tryb nocny.
- Postacie 3D z animacją: gracz, 4 typy wierzycieli, przechodnie z reakcjami na sytuację (auta, pościg, rzucane przedmioty, wydarzenia).
- Ruch uliczny: 9 typów nadwozia, losowe kolory i zmyślone marki.
- Obrona: rzucanie 6 rodzajów przedmiotów, zbieranie ich z toreb.

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

Nastrój nocy reguluje się w `shaders/common.gdshaderinc`: stałe `AMB_DUSK` i `AMB_NIGHT` (światło otoczenia)
oraz `lamps_on()` (kiedy zapalają się latarnie i okna).

## Dane

- `data/makow_grid.png`: siatka 1074×1001 kafli (R = klasa, G = klasa podłoża, B = pokrycie budynkiem).
- `data/buildings.json`: obrysy budynków (kafle), piętra, typ, dach.
- `tools/`: skrypty Pythona (w kolejności: `stitch`/`solve`/`mosaic`, `classify`, `regularize`, `buildings2`), z których powstały (scalanie zrzutów, klasyfikacja kolorów; zrzutów źródłowych nie ma w repo).

## Licencje i atrybucja

Układ ulic, budynków i terenów: © autorzy OpenStreetMap, licencja ODbL (https://www.openstreetmap.org/copyright).
Atrybucja jest widoczna w grze. Postacie, marki samochodów i nazwy są zmyślone.
