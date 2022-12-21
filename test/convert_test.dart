import 'dart:convert';

import 'package:calcupiano/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("Prototype of Custom JsonCodec", () {
    test("Map custom class", () {
      mapCustomClass();
    });

    test("Work with generated adapter", () {
      workWithGeneratedAdapter();
    });
  });
}

void workWithGeneratedAdapter() {
  final from = {
    "calcupiano.BundledSoundFile": BundledSoundFile.fromJson,
  };
  final to = {
    "calcupiano.BundledSoundFile": (obj) => obj.toJson(),
  };
  Object? reviver(Object? key, Object? value) {
    if (value is! Map) {
      return value;
    } else {
      final type = value["@type"];
      final fromFunc = from[type]!;
      return fromFunc(value as Map<String, dynamic>);
    }
  }

  Object? toEncodable(dynamic object) {
    if (object is Convertible) {
      final type = object.typeName;
      final toFunc = to[type]!;
      final json = toFunc(object);
      json["@type"] = type;
      return json;
    }
    return object;
  }

  final JsonCodec json = JsonCodec(reviver: reviver, toEncodable: toEncodable);
  const f = BundledSoundFile(pathInAssets: "default/1.wav");
  final res = json.encode(f);
  assert(res.contains('default/1.wav'));
  final restored = json.decode(res);
  assert(restored is! LocalSoundFile);
  assert((restored as BundledSoundFile).pathInAssets == "default/1.wav");
}

void mapCustomClass() {
  Object? reviver(Object? key, Object? value) {
    if (value is! Map) {
      return value;
    } else {
      return Foo(value["a"]);
    }
  }

  Object? toEncodable(dynamic object) {
    if (object is Foo) {
      return {"a": object.a};
    }
  }

  final JsonCodec json = JsonCodec(reviver: reviver, toEncodable: toEncodable);
  final ta = Foo("toJson");
  final res = json.encode(ta);
  assert(res == '{"a":"toJson"}');
  const fa = '{"a":"fromJson"}';
  final res2 = json.decode(fa) as Foo;
  assert(res2.a == "fromJson");
}

class Foo {
  final String a;

  Foo(this.a);
}
