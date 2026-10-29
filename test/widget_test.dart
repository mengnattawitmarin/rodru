import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rodru/app_state.dart';
import 'package:rodru/main.dart';
import 'package:rodru/services/api.dart';
import 'package:rodru/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app starts offline and shows home + SOS', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await Storage.open();
    // Every request fails → app must still render using offline content.
    final api = Api(client: MockClient((_) async => http.Response('offline', 503)));
    final state = AppState(storage, api: api);

    await tester.pumpWidget(RodruApp(state: state));
    await state.init();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('รอดรู้'), findsWidgets);
    expect(find.textContaining('SOS'), findsWidgets);
    expect(state.error, isNotNull);

    // Switch to the "เตรียมพร้อม" tab.
    await tester.tap(find.text('เตรียมพร้อม').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ความพร้อมของฉัน'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
