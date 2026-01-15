import 'package:flutter_test/flutter_test.dart';
import 'package:waiter/utils.dart';

void main() {
  group('InputSanitizer', () {
    test('sanitize removes HTML tags', () {
      expect(InputSanitizer.sanitize('<script>alert("xss")</script>'), equals('alert(xss)'));
      expect(InputSanitizer.sanitize('<div>Hello</div>'), equals('Hello'));
      expect(InputSanitizer.sanitize('<p onclick="evil()">Text</p>'), equals('Text'));
    });

    test('sanitize removes XSS patterns', () {
      expect(InputSanitizer.sanitize('javascript:alert(1)'), isEmpty);
      expect(InputSanitizer.sanitize('data:text/html,<script>'), isEmpty);
      expect(InputSanitizer.sanitize('onclick=alert(1)'), isEmpty);
    });

    test('sanitize handles null and empty input', () {
      expect(InputSanitizer.sanitize(null), equals(''));
      expect(InputSanitizer.sanitize(''), equals(''));
      expect(InputSanitizer.sanitize('   '), equals(''));
    });

    test('sanitize preserves normal text', () {
      expect(InputSanitizer.sanitize('Hello World'), equals('Hello World'));
      expect(InputSanitizer.sanitize('Order for table 5'), equals('Order for table 5'));
      expect(InputSanitizer.sanitize('No onions please'), equals('No onions please'));
    });

    test('sanitizeWithLimit enforces length limit', () {
      final longText = 'A' * 1000;
      final result = InputSanitizer.sanitizeWithLimit(longText, 100);
      expect(result.length, equals(100));
    });

    test('sanitizeCarPlate returns null for invalid input', () {
      expect(InputSanitizer.sanitizeCarPlate(null), isNull);
      expect(InputSanitizer.sanitizeCarPlate(''), isNull);
      expect(InputSanitizer.sanitizeCarPlate('AB'), isNull); // Too short
    });

    test('sanitizeCarPlate normalizes valid plates', () {
      expect(InputSanitizer.sanitizeCarPlate('abc 123'), equals('ABC 123'));
      expect(InputSanitizer.sanitizeCarPlate('xyz-789'), equals('XYZ-789'));
    });

    test('sanitizeCarPlate removes dangerous characters', () {
      expect(InputSanitizer.sanitizeCarPlate('<script>ABC</script>'), equals('SCRIPTABCSCRIPT'));
    });

    test('sanitizeInstructions limits length', () {
      final longInstructions = 'A' * 1000;
      final result = InputSanitizer.sanitizeInstructions(longInstructions);
      expect(result.length, equals(ValidationLimits.maxSpecialInstructionsLength));
    });
  });

  group('ValidationLimits', () {
    test('has reasonable default limits', () {
      expect(ValidationLimits.maxSpecialInstructionsLength, equals(500));
      expect(ValidationLimits.maxCarPlateLength, equals(15));
      expect(ValidationLimits.minCarPlateLength, equals(3));
      expect(ValidationLimits.maxItemsPerOrder, equals(50));
      expect(ValidationLimits.maxQuantityPerItem, equals(99));
    });
  });

  group('SessionManager', () {
    test('isSessionExpired returns false for fresh session', () {
      SessionManager.resetSession();
      expect(SessionManager.isSessionExpired(), isFalse);
    });

    test('updateActivity resets the session timer', () {
      SessionManager.updateActivity();
      expect(SessionManager.isSessionExpired(), isFalse);
    });
  });

  group('Validators', () {
    test('validateCarPlate accepts valid plates', () {
      expect(Validators.validateCarPlate('ABC 123'), isNull);
      expect(Validators.validateCarPlate('XYZ-789'), isNull);
      expect(Validators.validateCarPlate('A1B2C3'), isNull);
    });

    test('validateCarPlate rejects invalid plates', () {
      expect(Validators.validateCarPlate(null), isNotNull);
      expect(Validators.validateCarPlate(''), isNotNull);
      expect(Validators.validateCarPlate('   '), isNotNull);
    });

    test('validateSpecialInstructions accepts valid input', () {
      expect(Validators.validateSpecialInstructions('No onions'), isNull);
      expect(Validators.validateSpecialInstructions('Extra spicy please'), isNull);
      expect(Validators.validateSpecialInstructions(null), isNull); // Optional field
    });

    test('validateTableNumber accepts valid tables', () {
      expect(Validators.validateTableNumber('1'), isNull);
      expect(Validators.validateTableNumber('99'), isNull);
      expect(Validators.validateTableNumber('A1'), isNull);
    });

    test('validateTableNumber rejects invalid tables', () {
      expect(Validators.validateTableNumber(null), isNotNull);
      expect(Validators.validateTableNumber(''), isNotNull);
    });

    test('validateCart checks for empty carts', () {
      expect(Validators.validateCart([]), isNotNull);
      expect(Validators.validateCart([{'name': 'Item', 'quantity': 1}]), isNull);
    });
  });
}
