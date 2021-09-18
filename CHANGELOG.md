## 0.0.5

**Breaking changes**:
- Default file name pattern changes in `WarcFileWriter`.

## 0.0.4

**Breaking changes**:
- Renamed `WarcRecord.payload` to `block` (also: `WarcBlock`).
- `WarcBlock` and with that `WarcRecord` is now only synchronous.
- `readWarc` returns a stream instead of callback method.
- `CdxjRecord` follows `pywb` conventions.

## 0.0.3

- Extended `WarcHeader` with named parameters.
- Write CDXJ records based on written offsets. 

## 0.0.2

- Write support (+ compression and offset-tracking).

## 0.0.1

- Low-level read support.
