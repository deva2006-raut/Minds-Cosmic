# EARTHSONIC — LISTEN TO THE LIVING PLANET

**Explore Earth through sight, sound and science.**

EARTHSONIC turns authentic NASA Earth observations into interactive scientific visualisations and sound that is
generated live from the selected data. The product is one instrument with three panels:

```
SELECT LOCATION → SELECT REAL DATA → VISUALISE EARTH → GENERATE SOUND → UNDERSTAND THE SCIENCE
```

| Panel | Route | What it does |
| --- | --- | --- |
| 01 Earth Observatory | `/observatory` | 3D globe + 2D map, real GIBS imagery layers, location search/pick, date compare, layer opacity, provenance strip |
| 02 Earth Jukebox | `/jukebox` | Data-driven sonification studio: multi-track orchestra, mapping designer, presets, timeline, waveform, spectrum, recording, WAV export, project save |
| 03 Science Lab | `/lab` | Time series, two-location / two-period comparison, anomalies against the POWER climatology baseline, data card, CSV / PNG / PDF export, contextual assistant |

Secondary navigation only: `/projects`, `/settings`, `/help`.

## Run it

```bash
npm install
npm run dev      # http://localhost:3100
```

Port **3100** is used deliberately (an older prototype occupies 3000).

```bash
npm run build      # production build
npm run typecheck  # tsc --noEmit
npm test           # vitest run  (44 tests)
```

## Real NASA data only

| Source | Service | Used for | Credentials |
| --- | --- | --- | --- |
| NASA GIBS | WMTS/XYZ raster (`gibs.earthdata.nasa.gov`) | satellite imagery + scientific overlays | none |
| NASA POWER | `power.larc.nasa.gov/api/temporal/{daily,monthly,climatology}/point` | point time series, statistics, anomalies | none |
| NASA GISTEMP | `data.giss.nasa.gov/gistemp/tabledata_v4/GLB.Ts+dSST.csv` | global temperature record + baseline | none |
| NASA Worldview / Earthdata | linked as browse and download destinations | attribution, source links | none |

Server routes proxy and cache every request so the browser never talks to NASA directly:

- `GET /api/power?kind=daily|monthly|climatology&lat&lon&start&end&params`
- `GET /api/gistemp`
- `GET /api/tile?layer&date&z&x&y` (same-origin 4326 tile proxy used by the globe stitcher)
- `GET /api/layers/verify?layer&date` (HEAD availability probe + actual layer/time echoed by GIBS)
- `POST /api/assistant` (server-side LLM, see below)

### Transparency rules enforced in code

- The layer catalogue (`lib/nasa/gibs-catalog.json`) was generated from live GIBS capabilities. A layer is only
  rendered as available after `/api/layers/verify` confirms it for the selected date; vector-only products
  (thermal anomalies, fires) are listed as **unavailable, with the reason**, instead of being faked.
- Every value carries dataset name, source, unit, observation period, retrieval timestamp, processing method and a
  `cached` flag. Observation time and retrieval time are displayed separately.
- Missing POWER cells stay missing: charts break the line / skip the step, the data card reports
  `valid · missing · % complete`, and exports keep the gaps. Nothing is interpolated to fill a chart.
- Derived numbers are labelled **derived** (mean, min, max, rolling mean, anomaly, trend). The trend is fitted to
  **annual means** and only reported for windows of two years or more; shorter windows say so explicitly.
- Anomalies only appear when the POWER 2001–2025 climatology baseline is loaded, and the baseline period is printed
  with the chart.
- The Atlas layer set contains no simulated series. If a NASA service fails, the UI shows the upstream error and a
  retry — never demo values.

## Sonification

`lib/sonification/mapping.ts` builds a pure, testable score from the loaded series:

```
series (real observation values)
  → normalisation (min-max / robust percentile / z-score / absolute bounds)
  → pitch (continuous, stepped, or scale-quantised to a chosen mode)
  → rhythm (onset density, or value-driven gate)
  → instrument + frequency range + tempo
  → note events → Web Audio scheduling
```

- Six presets: Scientific, Ambient, Cinematic, Educational, Minimal, Accessibility.
- Multi-track orchestra with per-track mute / solo / volume, master volume, tempo, loop, duration.
- A scientific legend prints the actual data range, unit, frequency range and instrument used for every track.
- Changing location, dataset, date range or mapping rebuilds the score through `dataSignature` and **stops the
  playing engine** so old audio can never outlive its data.
- WAV export renders the same `scheduleVoice` path through `OfflineAudioContext`, so the exported file is the score
  you heard, not a separate renderer.

## AI assistant (optional)

`POST /api/assistant` calls any OpenAI-compatible chat-completions endpoint **from the server**. The key never
reaches the browser. Without configuration the panel states the requirement instead of inventing an answer.

```bash
cp .env.example .env.local
# OPENAI_API_KEY=...
# OPENAI_BASE_URL=https://api.openai.com/v1   (optional)
# OPENAI_MODEL=gpt-4o-mini                    (optional)
```

The system prompt forbids invented measurements, dates and NASA products, requires the
observation / derived / interpretation distinction, and supports English and Hindi.

## State model

`lib/state/exploration.tsx` holds one reducer for all three panels: location, compare location, dates, range,
layers, opacity, variable, chart configuration, sonification mapping, tracks, master volume, units and playback.
It is persisted to `localStorage` and shared by every route, so charts, map and audio cannot disagree.

Saved projects (`/projects`) also live in `localStorage` — documented as **local-only, not synced and not secure**
instead of a fake login.

## Verified behaviour

Checked against live services while building:

- `/`, `/observatory`, `/jukebox`, `/lab`, `/projects`, `/settings`, `/help` → 200, no console errors.
- GIBS: 15 tiles for `MODIS_Terra_CorrectedReflectance_TrueColor` at 2026-11-11 → 200 `image/png`, stitched into the
  globe texture; `/api/layers/verify` echoed the actual layer id and actual date.
- POWER daily: 12 parameters × 90 days → real values (`T2M` 2026-10-01 = 27.63 °C), 99 missing future cells reported
  as missing; 5-year window → 1 824 valid days, 99.9 % complete.
- POWER climatology: baseline period `January 2001 - December 2025`.
- GISTEMP: 147 annual records (1880–2026), 1 762 monthly records, baseline 1951–1980.
- Jukebox: 90 observations → 267 note events; play advanced the transport (0:06 / 0:36); stop reset it; offline WAV
  render completed; save/load round-tripped a project.
- Mobile viewport 390 × 844: no horizontal overflow, navigation and panels intact.

## Notes and limitations

- NASA POWER daily data lags: the most recent one to two days return `fill_value` (-999) and are shown as missing,
  not as zeros.
- NASA GISS closes the connection for HTTP clients that send no `User-Agent`; the proxy sends one.
- The globe is a custom three.js renderer with a GIBS-stitched texture (no CesiumJS, no MapLibre), so it needs WebGL 2.
- Thermal anomaly / fire layers are vector-only in GIBS and are therefore offered as unavailable rather than
  approximated with a raster layer.
- EARTHSONIC is an independent project built on public NASA data services. It is not a NASA product, not a digital
  twin of Earth, and its derived metrics are not NASA assessments.

## Tests

```
tests/power.test.ts        parsing, fill-value handling, aggregation, climatology, anomalies, annual-mean trend
tests/sonification.test.ts normalisation, pitch/rhythm mapping, determinism, presets, WAV encoding
tests/geo.test.ts          mercator/tile math, sphere projection, globe stitch geometry
tests/report.test.ts       PDF structure, escaping, page layout
```
