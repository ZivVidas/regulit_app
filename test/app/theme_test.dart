import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';

void main() {
  group('AppGradients.neutralHeader', () {
    test('is a LinearGradient with the correct two grey colors', () {
      expect(AppGradients.neutralHeader, isA<LinearGradient>());
      expect(AppGradients.neutralHeader.colors.length, 2);
      expect(AppGradients.neutralHeader.colors[0], const Color(0xFF8A8886));
      expect(AppGradients.neutralHeader.colors[1], const Color(0xFF605E5C));
    });
  });
}
