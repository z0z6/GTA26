# Uciekaj przed windykatorem

Gra w stylu GTA2 (widok z góry, 3D) na prawdziwym układzie miasta: Maków Mazowiecki z danych OpenStreetMap.
Uciekasz przed windykatorami, zbierasz monety, rzucasz w pościg czym popadnie i omijasz absurdy samorządowe.
Silnik: Godot 4.4 (GDScript, renderer Compatibility). Cel: Android.

## Co jest w grze

- Podłoże rysowane shaderem (gładkie granice terenów, chodniki, oznaczenia dróg, woda), budynki z wielokątów OSM
  z elewacjami, dachami spadzistymi i płaskimi, drzewa, latarnie, tryb nocny.
- Postacie 3D z animacją: gracz, 4 typy wierzycieli, przechodnie z reakcjami na sytuację (auta, pościg, rzucane przedmioty, wydarzenia).
- Ruch uliczny: 9 typów nadwozia, losowe kolory i zmyślone marki.
- Obrona: rzucanie 6 rodzajów przedmiotów, zbieranie ich z toreb.

## Uruchomienie

1. Otwórz projekt w Godot 4.4.x i naciśnij F5.
2. Sterowanie: strzałki/WASD (lub przeciąganie palcem), Shift = sprint, Spacja = rzut, N = dzień/noc, Enter = start.

## Testy (bez okna, jak w CI)

```
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . -- --autoplay=40 --steps=10
```

Podgląd do zrzutów (wymaga renderera, np. xvfb + opengl3):
`godot --rendering-driver opengl3 --path . -- --shot=plik.png --at=533,441 [--night] [--autoplay=20 --steps=10]`

## Android

Preset w `export_presets.cfg`, workflow `.github/workflows/android.yml` (Actions → Android build → Run workflow).
Wymagane ustawienie projektu `import_etc2_astc=true` jest już włączone.

## Dane

- `data/makow_grid.png`: siatka 1074×1001 kafli (R = klasa, G = klasa podłoża, B = pokrycie budynkiem).
- `data/buildings.json`: obrysy budynków (kafle), piętra, typ, dach.
- `tools/`: skrypty Pythona, z których powstały (scalanie zrzutów, klasyfikacja kolorów; zrzutów źródłowych nie ma w repo).

## Licencje i atrybucja

Układ ulic, budynków i terenów: © autorzy OpenStreetMap, licencja ODbL (https://www.openstreetmap.org/copyright).
Atrybucja jest widoczna w grze. Postacie, marki samochodów i nazwy są zmyślone.
