import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_shop_app_with_nosql/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('dashboard opens and sidebar navigation changes sections', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LaundryShopApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.textContaining('Connect your CouchDB database'),
      findsOneWidget,
    );

    await tester.tap(find.text('Customers').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Connect CouchDB in Settings to use this feature.'),
      findsOneWidget,
    );
    expect(find.text('Customers'), findsNWidgets(2));

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    expect(find.text('CouchDB connection'), findsOneWidget);
    expect(find.text('Test CRUD operations'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'CouchDB base URL'),
      'http://localhost:5984',
    );
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    expect(
      find.text('Connection address and database saved on this computer.'),
      findsOneWidget,
    );
  });
}
