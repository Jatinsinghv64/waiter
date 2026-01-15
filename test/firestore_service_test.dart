import 'package:flutter_test/flutter_test.dart';
import 'package:waiter/Firebase/FirestoreService.dart';

void main() {
  group('isValidStatusTransition', () {
    test('allows valid forward transitions', () {
      // New order can start as pending or preparing
      expect(FirestoreService.isValidStatusTransition(null, 'pending'), isTrue);
      expect(FirestoreService.isValidStatusTransition(null, 'preparing'), isTrue);
      expect(FirestoreService.isValidStatusTransition('', 'pending'), isTrue);
      expect(FirestoreService.isValidStatusTransition('', 'preparing'), isTrue);
      
      // Standard forward flow
      expect(FirestoreService.isValidStatusTransition('pending', 'preparing'), isTrue);
      expect(FirestoreService.isValidStatusTransition('preparing', 'prepared'), isTrue);
      expect(FirestoreService.isValidStatusTransition('prepared', 'served'), isTrue);
      expect(FirestoreService.isValidStatusTransition('served', 'paid'), isTrue);
      
      // Cancellation allowed at various stages
      expect(FirestoreService.isValidStatusTransition('pending', 'cancelled'), isTrue);
      expect(FirestoreService.isValidStatusTransition('preparing', 'cancelled'), isTrue);
      expect(FirestoreService.isValidStatusTransition('prepared', 'cancelled'), isTrue);
    });

    test('blocks invalid forward transitions', () {
      // Cannot skip stages
      expect(FirestoreService.isValidStatusTransition('pending', 'prepared'), isFalse);
      expect(FirestoreService.isValidStatusTransition('pending', 'served'), isFalse);
      expect(FirestoreService.isValidStatusTransition('preparing', 'served'), isFalse);
      
      // Terminal states cannot transition
      expect(FirestoreService.isValidStatusTransition('paid', 'pending'), isFalse);
      expect(FirestoreService.isValidStatusTransition('cancelled', 'pending'), isFalse);
      expect(FirestoreService.isValidStatusTransition('returned', 'pending'), isFalse);
    });

    test('blocks backward transitions when allowBackward is false', () {
      expect(FirestoreService.isValidStatusTransition('preparing', 'pending'), isFalse);
      expect(FirestoreService.isValidStatusTransition('prepared', 'preparing'), isFalse);
      expect(FirestoreService.isValidStatusTransition('served', 'prepared'), isFalse);
    });

    test('allows backward transitions when allowBackward is true', () {
      expect(
        FirestoreService.isValidStatusTransition('preparing', 'pending', allowBackward: true), 
        isTrue,
      );
      expect(
        FirestoreService.isValidStatusTransition('prepared', 'preparing', allowBackward: true), 
        isTrue,
      );
      expect(
        FirestoreService.isValidStatusTransition('served', 'prepared', allowBackward: true), 
        isTrue,
      );
    });

    test('allows exchange flow from delivered to preparing', () {
      expect(FirestoreService.isValidStatusTransition('delivered', 'preparing'), isTrue);
    });
  });

  group('getValidNextStatuses', () {
    test('returns correct forward transitions', () {
      expect(FirestoreService.getValidNextStatuses(null), containsAll(['pending', 'preparing']));
      expect(FirestoreService.getValidNextStatuses('pending'), containsAll(['preparing', 'cancelled']));
      expect(FirestoreService.getValidNextStatuses('preparing'), containsAll(['prepared', 'cancelled']));
      expect(FirestoreService.getValidNextStatuses('prepared'), containsAll(['served', 'paid', 'cancelled']));
      expect(FirestoreService.getValidNextStatuses('served'), containsAll(['paid', 'cancelled']));
    });

    test('returns empty list for terminal states', () {
      expect(FirestoreService.getValidNextStatuses('paid'), isEmpty);
      expect(FirestoreService.getValidNextStatuses('cancelled'), isEmpty);
      expect(FirestoreService.getValidNextStatuses('returned'), isEmpty);
    });

    test('includes backward transitions when includeBackward is true', () {
      expect(
        FirestoreService.getValidNextStatuses('preparing', includeBackward: true), 
        contains('pending'),
      );
      expect(
        FirestoreService.getValidNextStatuses('prepared', includeBackward: true), 
        contains('preparing'),
      );
      expect(
        FirestoreService.getValidNextStatuses('served', includeBackward: true), 
        contains('prepared'),
      );
    });
  });
}
