import 'dart:collection';

const lineFeed = 10;
const carriageReturn = 13;

class CaseInsensitiveMap<V> extends MapBase<String, V> {
  final Map<String, V> _values;

  CaseInsensitiveMap(Map<String, V> values) : _values = <String, V>{...values};

  @override
  V? operator [](Object? key) {
    if (_values.containsKey(key)) {
      return _values[key];
    }
    final lc = key.toString().toLowerCase();
    for (final k in keys) {
      if (k.toLowerCase() == lc) {
        return _values[k];
      }
    }
    return null;
  }

  @override
  void operator []=(String key, V value) {
    _values[key] = value;
  }

  @override
  void clear() {
    _values.clear();
  }

  @override
  Iterable<String> get keys => _values.keys;

  @override
  V? remove(Object? key) {
    return _values.remove(key);
  }
}
