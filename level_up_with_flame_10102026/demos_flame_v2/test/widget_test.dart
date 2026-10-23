import 'package:flame_showcase/demos/seats/seat_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seat layout makes the requested number of seats', () {
    final l = SeatLayout(5000);
    expect(l.n, 5000);
    expect(l.bounds.width, greaterThan(0));
  });
}
