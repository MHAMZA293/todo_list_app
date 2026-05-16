import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taskify/main.dart';

void main() {
  // Clear shared_preferences before every test so state doesn't bleed between runs.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  // ─── Smoke test ────────────────────────────────────────────────────────────

  testWidgets('App launches and shows Taskify header',
          (WidgetTester tester) async {
        await tester.pumpWidget(const TodoApp());
        await tester.pumpAndSettle();

        expect(find.text('Taskify'), findsOneWidget);
      });

  // ─── Empty state ───────────────────────────────────────────────────────────

  testWidgets('Empty state message is shown when there are no tasks',
          (WidgetTester tester) async {
        await tester.pumpWidget(const TodoApp());
        await tester.pumpAndSettle();

        expect(find.text('All clear!'), findsOneWidget);
        expect(find.text('Tap + to add your first task'), findsOneWidget);
      });

  // ─── Add task ──────────────────────────────────────────────────────────────

  testWidgets('Can add a new task via the bottom sheet',
          (WidgetTester tester) async {
        await tester.pumpWidget(const TodoApp());
        await tester.pumpAndSettle();

        // Open add-task sheet via FAB label
        await tester.tap(find.text('New Task'));
        await tester.pumpAndSettle();

        // Type a task title
        await tester.enterText(
          find.byType(TextField).first,
          'Buy groceries',
        );

        // Tap the Add Task button inside the sheet
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
        await tester.pumpAndSettle();

        // Task should now appear in the list
        expect(find.text('Buy groceries'), findsOneWidget);
        // Empty state should be gone
        expect(find.text('All clear!'), findsNothing);
      });

  // ─── Complete task ─────────────────────────────────────────────────────────

  testWidgets('Tapping the checkbox marks a task as done',
          (WidgetTester tester) async {
        await tester.pumpWidget(const TodoApp());
        await tester.pumpAndSettle();

        // Add a task first
        await tester.tap(find.text('New Task'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Read a book');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
        await tester.pumpAndSettle();

        // Tap the animated checkbox (first AnimatedContainer inside the card)
        final checkbox = find.byWidgetPredicate(
              (w) =>
          w is AnimatedContainer &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius != null,
        ).first;

        await tester.tap(checkbox);
        await tester.pumpAndSettle();

        // "Completed" section header should now be visible
        expect(find.text('Completed'), findsOneWidget);
      });

  // ─── Delete task ───────────────────────────────────────────────────────────

  testWidgets('Swiping a task card removes it from the list',
          (WidgetTester tester) async {
        await tester.pumpWidget(const TodoApp());
        await tester.pumpAndSettle();

        // Add a task
        await tester.tap(find.text('New Task'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Go for a walk');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
        await tester.pumpAndSettle();

        expect(find.text('Go for a walk'), findsOneWidget);

        // Swipe left to delete
        await tester.drag(
          find.text('Go for a walk'),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        expect(find.text('Go for a walk'), findsNothing);
        expect(find.text('All clear!'), findsOneWidget);
      });

  // ─── Edit task ─────────────────────────────────────────────────────────────

  testWidgets('Long-pressing a task opens the edit dialog',
          (WidgetTester tester) async {
        await tester.pumpWidget(const TodoApp());
        await tester.pumpAndSettle();

        // Add a task
        await tester.tap(find.text('New Task'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Old title');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
        await tester.pumpAndSettle();

        // Long-press the card to open the edit dialog
        await tester.longPress(find.text('Old title'));
        await tester.pumpAndSettle();

        // Edit dialog should appear
        expect(find.text('Edit Task'), findsOneWidget);

        // Clear and type new title
        await tester.enterText(find.byType(TextField).last, 'New title');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await tester.pumpAndSettle();

        expect(find.text('New title'), findsOneWidget);
        expect(find.text('Old title'), findsNothing);
      });

  // ─── Category filter ───────────────────────────────────────────────────────

  testWidgets('Category chips filter the task list', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    // Add a Personal task (default category)
    await tester.tap(find.text('New Task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Personal task');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
    await tester.pumpAndSettle();

    // Switch to Work filter — Personal task should disappear
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('Personal task'), findsNothing);
    expect(find.text('All clear!'), findsOneWidget);

    // Switch back to All — task reappears
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Personal task'), findsOneWidget);
  });

  // ─── Progress bar ──────────────────────────────────────────────────────────

  testWidgets('Progress label updates when a task is completed',
          (WidgetTester tester) async {
        await tester.pumpWidget(const TodoApp());
        await tester.pumpAndSettle();

        // Add a task
        await tester.tap(find.text('New Task'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Write tests');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
        await tester.pumpAndSettle();

        // Before completion: 0 of 1
        expect(find.text('0 of 1 tasks done'), findsOneWidget);

        // Mark done
        final checkbox = find.byWidgetPredicate(
              (w) =>
          w is AnimatedContainer &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius != null,
        ).first;
        await tester.tap(checkbox);
        await tester.pumpAndSettle();

        // After completion: 1 of 1
        expect(find.text('1 of 1 tasks done'), findsOneWidget);
      });
}